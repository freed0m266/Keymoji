# App Store listing — Čeština (sekundární locale)

> Zdroj pravdy pro českou metadata v App Store Connect. Pole zkopírovat doslova.
> Diakritika se počítá jako 1 znak. Délky ověřit přes
> `marketing/app-store/check-lengths.sh`.
>
> Pozicování: **emoji-first**. Hrdinou jsou personalizované emoji (oblíbené,
> vlastní pořadí, emoji řada, hledání podle názvu / `:zkratky:`) plus to nejlepší
> z nativní klávesnice a SwiftKey. Soukromí je podpůrný argument, ne headline.

## Název aplikace (max 30)

> Pozn.: „Emoji" jako popis je skvělé na ASO, ale slovo má ochrannou známku
> Emoji Company GmbH. Popisné použití v metadatech je běžné a méně rizikové než
> brand use; konzervativní varianta je „Keymoji – Vlastní klávesnice".

```
Keymoji – Emoji klávesnice
```

## Podtitul (max 30)

```
Oblíbené, hledání, zkratky
```

## Klíčová slova (max 100, oddělená čárkou, bez mezer)

Slova z názvu (Keymoji, Emoji, klávesnice) a podtitulu (oblíbené, hledání,
zkratky) se indexují automaticky — neopakovat je.

```
smajlíky,qwerty,qwertz,unicode,symboly,haptika,nativní,rychlá,psaní,soukromá,offline,návrhy,vlastní
```

## Propagační text (max 170, měnitelný bez review)

```
Tvé emoji po tvém: připni oblíbené, nastav jejich pořadí a ťukej je z emoji řady nad klávesami. Hledej emoji podle názvu nebo :zkratky:. Rychlá, nativní, bez sledování.
```

## Popis (max 4000)

```
Keymoji je klávesnice pro iPhone pro lidi, kteří žijí v emoji. Tvé oblíbené emoji máš jeden tap daleko — v pořadí, které si určíš TY — a přitom si drží rychlý, známý pocit nativní klávesnice, kterou znáš.

Ber to jako to nejlepší z obou světů: přesnost a nativní pocit klávesnice od Applu plus sílu, kterou bys čekal od SwiftKey — bez balastu a bez sledování.

EMOJI PO TVÉM

• Vyber si oblíbené emoji a seřaď je ve vlastním pořadí
• Emoji řada sedí přímo nad klávesami — tvá top emoji vždy jeden tap daleko
• Hledej jakékoli emoji podle názvu — prostě napiš, co myslíš
• Zkratky ve stylu Slacku — napiš :smile: a dostaneš emoji
• Kompletní katalog jednoznakových emoji, vestavěný

KLÁVESNICE, CO SEDÍ

• Nativní vzhled a pocit — navržená tak, aby působila jako iOS, žádný rušivý redesign
• Stálá číselná řada — číslice bez přepínání rozložení
• QWERTY i QWERTZ, přepnutí jedním tapem
• Chytré návrhy slov, které se učí slova, jež opravdu používáš
• Dlouhý stisk klávesy pro diakritiku a akcenty
• Trackpad kurzor — dlouhým stiskem mezerníku přesně posouváš kurzor
• Mazání po slovech při delším podržení
• Haptická odezva a zvuky kláves, plně nastavitelné
• Vlastní přepínání světlého/tmavého vzhledu nezávisle na systému

SOUKROMÁ VE VÝCHOZÍM STAVU

Keymoji je k tomu příjemně soukromá — ne jako trik, ale protože je jednoduchá. Neposílá žádné síťové požadavky: neobsahuje žádný síťový kód, takže co píšeš, nikdy neopustí tvůj iPhone. Žádné analytics, žádné sledování, žádné účty, žádné SDK třetích stran. Slova, která se naučí pro zrychlení psaní, zůstávají v soukromém kontejneru, ke kterému má přístup jen Keymoji — nikdy se nenahrávají, ani k Applu. Zdrojový kód je veřejný na GitHubu.

O „POVOLIT PLNÝ PŘÍSTUP"

iOS vyžaduje, aby vlastní klávesnice měly zapnutý „Povolit plný přístup", než mohou používat API pro haptickou odezvu a zvuky kláves. To je pravidlo sandboxu iOS, ne přepínač sběru dat. Keymoji používá plný přístup výhradně pro:

• Haptickou odezvu (vibrace) při psaní
• Zvuky kláves

Keymoji nikdy nepoužívá plný přístup pro síť, kontakty, polohu ani cokoli jiného — neobsahuje vůbec žádný síťový kód. Pokud nechceš haptiku ani zvuk, můžeš plný přístup nechat vypnutý a zbytek klávesnice funguje úplně stejně.

Pouze iPhone. Anglická klávesnice.
```

## URL podpory

```
https://github.com/freed0m266/Keymoji
```

## Marketingové URL (volitelné)

```
https://martinfreedom.com/keymoji
```

## URL zásad ochrany soukromí

```
https://martinfreedom.com/keymoji/privacy.html
```
