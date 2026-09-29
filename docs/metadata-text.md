# Metadata text

What a descriptive metadata value may hold, how the markup inside it reaches the
screen, and the caption track an audio or video Work carries alongside it.

Source files:

- `app/helpers/enhanced_text_helper.rb`
- `app/services/metadata/control_characters.rb`
- `app/services/metadata/double_escapes.rb`
- `app/services/caption_track.rb`

## Rendering a subscript or a superscript

MODS has no element for a subscript. A chemistry or physics title records one by
escaping the tags into the title's own text node — `Bi&lt;sub&gt;2&lt;/sub&gt;`.
Reading that back gives the literal string `Bi<sub>2</sub>`, which the view
escapes again on output, so a reader sees the tags instead of the formula.
`EnhancedTextHelper` closes that loop.

### Which helper to call

There are three. The same string lands in two kinds of place, and an abstract
also carries paragraphs.

| Helper | Use it for | Why |
|---|---|---|
| `enhanced_text` | Element content | A subscript can actually render there |
| `enhanced_paragraphs` | A multi-paragraph description, such as a Collection's or Community's | It wraps each paragraph in `<p>` and runs each through `enhanced_text` |
| `plain_text` | An attribute, a page `<title>`, a citation meta tag, or anything about to be truncated | Markup can only ever show up as literal characters there, or a cut could sever a tag |

`plain_text` returns an ordinary String, not `html_safe` output, so it composes.
The caller can interpolate it into a sentence, or hand it to `tag.meta` and let
that escape it once.

Truncation goes through `plain_text` too. `truncate` counts characters and knows
nothing about tags, so cutting the markup-bearing string can sever one.

### Paragraphs follow Atlas's rules

`enhanced_paragraphs` splits on one or more blank lines (`PARAGRAPH_BREAK`,
which tolerates the trailing spaces a textarea collects). A lone newline is a
wrap, not a break, and becomes a space. Those rules are Atlas's: its decorator
projects the same abstract into `<p>` elements that way. A Work's show page and
a container's must agree about one stored value. The `<p>` wrappers are built in
the helper, never taken from the value, so the no-parsing rule below still
holds.

### Never parse the value as HTML

Both helpers work by pattern. A title is free text, and `<` is a character a
physics title uses for its own sake.

Handing `Ti <Tc in Bi<sub>2</sub>O` to an HTML parser opens a bogus element at
`<Tc` that swallows everything up to the next `>`. The value renders as
`Ti 2O`: the span is gone, and the subscript with it. How much is lost depends
on where that bracket falls. A record that correctly escapes its less-than as
`&lt;Tc` produces exactly that text, so well-formed MODS triggers the fault.

### The constants

`ENHANCED_TAGS` is the entire allowlist: the two inline tags carrying meaning a
reader cannot recover from the plain characters.

`ESCAPES` (matched by `ESCAPE_PATTERN`) holds the three characters an HTML text
node must escape. The quote characters are deliberately absent. They matter only
inside an attribute value, and this output is always element text. Escaping an
apostrophe would show up as `&#39;` in an ordinary possessive title.

`ESCAPED_TAG` matches an allowlisted tag in its escaped form, and bare — no
attributes. It ignores case, and `enhanced_text` revives the tag in lower case.
The bare-only match is what makes the revival safe, and what makes the helper's
`html_safe` safe. The escaped form of a tag
carrying anything (`<sub onmouseover=…>`) cannot match, so it can never come back
as markup.

`TAG_PATTERN` matches an opening or closing allowlisted tag, attributes and all.
Removal tolerates attributes because a page title or an `alt` attribute must not
carry `class="x"` either.

### A tag outside the allowlist stays visible

`enhanced_text` escapes everything, then revives only a bare allowlisted tag. A
tag outside the allowlist stays as source text rather than being tidied away. For
a repository that is the better failure: a curator can see the mistake and fix
the record, and nothing executes either way.

### Keep it identical to Atlas

Atlas's `EnhancedText` is the reference for both algorithms, and Atlas's
decorator renders the MODS block beside these headings. The two must agree
character for character. Change them together.

## Characters XML cannot store

`Metadata::ControlCharacters` reduces curator text to what XML 1.0 can actually
store.

XML 1.0's Char production admits tab, newline and carriage return, but no other
C0 control and no noncharacter. That holds even for a character reference, so
there is no encoding that smuggles one through. Nokogiri answers by dropping the
character when it serializes a text node, which is worse than a refusal. A
manual line break pasted out of Word disappears. The words either side of it run
together in the stored MODS and in the search index. Nothing on the screen says
so.

### Separators are mapped, the rest are dropped

The two separator controls are mapped, not deleted. Word writes a manual line
break as U+000B and a page break as U+000C. So each one stands for a boundary
the curator can see in the source document. Whitespace keeps that boundary where
deleting loses it. The rest carry no meaning and are dropped.

`DISCARD_CODEPOINTS` is what is left once tab, newline, carriage return and the
separators are accounted for. That is the rest of C0, plus the two noncharacters
at the top of the BMP that libxml2 rejects alongside them.

### What this deliberately does not touch

This is narrower than `NEU::MODS.normalize`, which also folds dashes and
transliterates smart punctuation. That vocabulary belongs on the access copy the
gem projects for display and search. These values are written into the
preservation XML, so nothing is touched here beyond what XML has no
representation for.

DEL and the C1 controls (U+007F..U+009F) are legal in XML 1.0 and are left alone.
U+0091 and U+0092 are the Windows-1252 mojibake signature: a data-quality signal
worth a report, not a character this has any right to rewrite. The gem's
access-copy normalizer already keeps them out of display and search.

### Which cleaner to call

| Method | Field | Separator becomes |
|---|---|---|
| `ControlCharacters.clean_line` | A title, a title part, a keyword, a name — anything that renders on one line | A space |
| `ControlCharacters.clean_text` | An abstract, or a whole raw MODS document | A newline |

`clean_line` uses a space because those values round-trip through a text input,
which cannot hold a newline. Pre-filling the edit form with one and saving would
change the stored value a second time, silently. That happens on a save the
curator meant as a no-op.

`clean_text` keeps the break the curator made. The gem's access-copy projection
folds it back to a space for display and search, so nothing downstream has to
know it is there.

Both cleaners pass `nil` through unchanged. `MODSMerge` reads a nil field as
"leave this alone", where `""` would mean "empty it".

`ControlCharacters.any?` answers whether a string holds an unstorable character
at all. `XmlController` uses it to decide whether to offer the repair.

### Reporting it to a curator

`ControlCharacters.report` is written for the curator reading a validation panel.
For the same input, libxml answers `PCDATA invalid Char value 11`, which names
neither the character, nor where it came from, nor what to do about it.

`DESCRIPTIONS` carries plain-language names for the characters a curator
plausibly pastes: a null, and Word's two breaks. Anything else is reported by
codepoint alone rather than guessed at.

`first_lines` returns one entry per codepoint rather than per occurrence, each
with the line it first appears on. A paste carries dozens, and listing every one
buries the fix the message is there to give.

## References escaped twice

`Metadata::DoubleEscapes` finds and repairs an entity reference that was escaped
a second time on its way into storage.

`&amp;lt;` in the source is the escaped form of the *text* `&lt;`. So the reader
sees the escape rather than the `<` the record means. The document is perfectly
well-formed, which is why nothing else catches it. Only a human can see that the
record meant a character and stored its spelling instead.

### Where it comes from

It arrives from a display pipeline that wrote text into HTML unescaped, where
escaping twice was the only way to make a `<` visible.

A record can hold both depths at once — a title escaped once, an abstract escaped
twice. So the record's own correct fields are the reference for what the rest
should hold.

### Only the five predefined entities

`CHARACTERS` holds the five named entities XML 1.0 predefines (`lt`, `gt`,
`amp`, `quot`, `apos`), each mapped to the character the reader should have
been shown. `NESTED_RE` matches `&amp;` followed by one of them.

Nothing else is recognised. Decoding `&amp;nbsp;` would produce `&nbsp;`, which
XML cannot parse, turning a valid document into one that no longer loads. A
numeric reference cannot appear at this depth, because the pipeline that produced
these deleted numeric references outright.

### One level per repair

`DoubleEscapes.decode` takes one level off every nested reference and touches
nothing else. One level is the defect, and a document three deep is rare enough
to be worth a second look. The advisory returns after a repair while any depth
remains, so pressing again is the way through.

### Raw source, not parsed nodes

Detection and repair both work on the raw source. A reference inside a comment or
an attribute is treated the same as one in an element. The curator reads the
result in the editor before saving it, which is what makes that breadth safe.

### Reporting it to a curator

`DoubleEscapes.report` is written for a curator reading an advisory. The XML is
valid, so this is the only place the problem can be named at all.

`consequence` spells the escape out with the first finding, so the sentence names
real characters rather than describing a class of them. That wording — "`&lt;`
where the record means `<`" — is the whole problem in six words.

`first_lines` returns one entry per reference rather than per occurrence. A
migrated abstract carries the same one in every paragraph, and listing every hit
buries the fix the message exists to give. It keeps reading order through the
Hash's insertion order. Sorting the pairs would order the message by entity name
instead, and send the curator up and down the buffer.

## The caption track

`CaptionTrack` answers three questions about an audio or video Work's captions:
which Blob is the caption, whether to offer the field at all, and whether an
upload is acceptable. `CaptionJob` does the writing — see `docs/derivatives.md`.
`WorkCaptions` (`app/controllers/concerns/work_captions.rb`) takes the upload.

### One track, labelled English

That is the whole of what the repository can currently say. A Blob carries a mime
type and a filename and nothing a `<track>` wants. Atlas has no field for a
caption's language or its display label. So a second caption could be stored but
never told apart from the first. The offer therefore matches what can be
described, and a multi-language Work waits on Atlas growing somewhere to put the
language.

`LANGUAGE` (`en`) and `LABEL` (`English`) are the srclang/label pair every
track carries, since nothing records the real ones. `works/_caption_source`
writes them onto the `<track>`. English matches v1, which hardcoded exactly
this.

`DOWNLOAD_LABEL` names the caption's row on the downloads list `Captions`.
Atlas labels every text Blob "Text Document", which says nothing about what the
file is for.

### WebVTT only

A browser `<track>` parses no other format, and Cerberus does not convert SRT.
`WorkCaptions` refuses an `.srt` upload with `CaptionTrack::REFUSED` rather than
storing a file no player will read. The file input's `accept` is `.vtt` too.

`CaptionTrack.accepted?` tests the extension rather than sniffed content. WebVTT
is plain text, so a sniffer reports `text/plain` for a perfectly good caption
file. Atlas itself types the stored Blob `text/vtt` off the name.

### Finding the caption Blob

`CaptionTrack.caption?` tells a caption by **MIME type**, `text/vtt`, never by
role. Atlas gives every content Blob the role `original_file`, the video master
included, so the role cannot tell them apart.

`CaptionTrack.for` finds at most one, because `CaptionJob` updates the bytes of
the Blob it finds rather than creating a second. Delegates — the image tiers —
carry a `uri` and are not content. `MediaRemux.playable_file` applies the same
test.

### Audio and video

`CaptionTrack.applicable?` offers captions on audio as well as video. v1 offered
them on video only, and the librarians asked for audio too.

A plain `<audio>` element is one control bar tall and has nowhere to draw a
caption. So `works/_av_player` mounts captioned audio on a `<video>` element in
video.js's `audioPosterMode`, the same element a poster already puts it on.
Posterless audio without captions keeps the plain `<audio>` player.

The caption rides `/media`, not `/downloads`. A caption is part of playing the
file, so anyone who can play it must reach it. The download gate that a
Streaming Only recording closes would otherwise take its captions down too.

It is deliberately its own predicate rather than `StreamingOnly.applicable?`,
which tests the same thing today for an unrelated reason. They are two features
that happen to agree, not one rule.
