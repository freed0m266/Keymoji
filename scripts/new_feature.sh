#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 NAME" >&2
    exit 1
fi

raw_name="$1"
if [[ ! "$raw_name" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    echo "NAME must match ^[A-Za-z][A-Za-z0-9]*$" >&2
    exit 1
fi

first_char_upper="$(printf '%s' "${raw_name:0:1}" | tr '[:lower:]' '[:upper:]')"
name_pascal="${first_char_upper}${raw_name:1}"
first_char_lower="$(printf '%s' "${name_pascal:0:1}" | tr '[:upper:]' '[:lower:]')"
name_camel="${first_char_lower}${name_pascal:1}"
created_date="$(date '+%d.%m.%Y')"

feature_keybo_dir="Features/Example"
feature_destination_dir="Features/${name_pascal}"
tuist_feature_file="Tuist/ProjectDescriptionHelpers/Targets/Features/${name_pascal}.swift"
project_manifest="Project.swift"
app_manifest="Tuist/ProjectDescriptionHelpers/Targets/App.swift"

for required_path in "$feature_keybo_dir" "$project_manifest" "$app_manifest"; do
    if [[ ! -e "$required_path" ]]; then
        echo "Required path not found: $required_path" >&2
        exit 1
    fi
done

if [[ -e "$feature_destination_dir" ]]; then
    echo "Feature already exists: $feature_destination_dir" >&2
    exit 1
fi

if [[ -e "$tuist_feature_file" ]]; then
    echo "Tuist feature already exists: $tuist_feature_file" >&2
    exit 1
fi

cp -R "$feature_keybo_dir" "$feature_destination_dir"

# Rename files/directories whose names contain Example/example.
while IFS= read -r -d '' path; do
    dir_name="$(dirname "$path")"
    base_name="$(basename "$path")"
    new_base_name="${base_name//Example/$name_pascal}"
    new_base_name="${new_base_name//example/$name_camel}"

    if [[ "$new_base_name" != "$base_name" ]]; then
        mv "$path" "$dir_name/$new_base_name"
    fi
done < <(find "$feature_destination_dir" -depth \( -name '*Example*' -o -name '*example*' \) -print0)

# Update file contents from Example/example to new names.
while IFS= read -r -d '' file; do
    perl -pi -e "s/Example/${name_pascal}/g; s/example/${name_camel}/g" "$file"
    CREATED_DATE="$created_date" perl -pi -e 's#(//\s+Created by Martin Svoboda on )\d{2}\.\d{2}\.\d{4}(\.)#$1.$ENV{CREATED_DATE}.$2#e' "$file"
done < <(find "$feature_destination_dir" -type f ! -name '.DS_Store' -print0)

cat > "$tuist_feature_file" <<TUIST
import Foundation

public let ${name_camel} = Feature(
	name: "${name_pascal}",
	dependencies: [
		.target(name: core.name),
		.target(name: designSystem.name),
		.target(name: resources.name)
	],
	hasTests: true,
	hasTesting: true
)
TUIST

insert_feature_in_project_manifest() {
    local entry="$1"
    local file="$2"
    local tmp

    if grep -Eq "^[[:space:]]*${entry},[[:space:]]*$" "$file"; then
        return
    fi

    tmp="$(mktemp)"

    awk -v entry="$entry" '
        BEGIN {
            inFeatures = 0
            inserted = 0
        }

        /^let features: \[Feature\] = \[/ {
            inFeatures = 1
            print
            next
        }

        inFeatures {
            if ($0 ~ /^\]/) {
                if (!inserted) {
                    print "\t" entry ","
                    inserted = 1
                }
                inFeatures = 0
                print
                next
            }

            if (!inserted && $0 ~ /^[[:space:]]*[A-Za-z0-9_]+,[[:space:]]*$/) {
                current = $0
                gsub(/^[[:space:]]+/, "", current)
                sub(/,[[:space:]]*$/, "", current)
                if (entry < current) {
                    print "\t" entry ","
                    inserted = 1
                }
            }

            print
            next
        }

        {
            print
        }

        END {
            if (!inserted) {
                exit 2
            }
        }
    ' "$file" > "$tmp" || {
        rm -f "$tmp"
        echo "Failed to insert ${entry} into $file" >&2
        exit 1
    }

    mv "$tmp" "$file"
}

insert_dependency_in_app_manifest() {
    local entry="$1"
    local file="$2"
    local tmp

    if grep -Eq "^[[:space:]]*\.target\(${entry}\),[[:space:]]*$" "$file"; then
        return
    fi

    tmp="$(mktemp)"

    awk -v entry="$entry" '
        BEGIN {
            inDeps = 0
            inserted = 0
        }

        /dependencies:[[:space:]]*\[/ {
            inDeps = 1
            print
            next
        }

        inDeps {
            if ($0 ~ /^[[:space:]]*\],?[[:space:]]*$/) {
                if (!inserted) {
                    print "\t\t.target(" entry "),"
                    inserted = 1
                }
                inDeps = 0
                print
                next
            }

            if (!inserted && $0 ~ /^[[:space:]]*\.target\([A-Za-z0-9_]+\),[[:space:]]*$/) {
                current = $0
                gsub(/^[[:space:]]*\.target\(/, "", current)
                sub(/\),[[:space:]]*$/, "", current)
                if (entry < current) {
                    print "\t\t.target(" entry "),"
                    inserted = 1
                }
            }

            print
            next
        }

        {
            print
        }

        END {
            if (!inserted) {
                exit 2
            }
        }
    ' "$file" > "$tmp" || {
        rm -f "$tmp"
        echo "Failed to insert .target(${entry}) into $file" >&2
        exit 1
    }

    mv "$tmp" "$file"
}

insert_feature_in_project_manifest "$name_camel" "$project_manifest"
insert_dependency_in_app_manifest "$name_camel" "$app_manifest"

echo "🎉 Created feature ${name_pascal}."
echo "- ${feature_destination_dir}"
echo "- ${tuist_feature_file}"
echo "- Updated ${project_manifest}"
echo "- Updated ${app_manifest}"
