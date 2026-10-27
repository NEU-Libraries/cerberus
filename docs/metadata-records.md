# Metadata records

A Work's additional metadata records: documents that sit beside its MODS, one
per format. Darwin Core is the only format so far. Atlas stores the record,
renders it and keeps its history; Cerberus validates it, shows it, and offers
the ways to write it.

Source files:

- `app/lib/darwin_core_record.rb`
- `app/controllers/darwin_core_records_controller.rb`
- `app/views/works/_darwin_core_edit.html.haml`
- `app/services/darwin_core_record_validator.rb`
- `app/jobs/xml_ingest_job.rb` (the Darwin Core step only)

Validation is covered in [`ingest.md`](ingest.md#darwin-core-records), with the
corrected TDWG schemas it needs.

## Whether a Work holds a record

`DarwinCoreRecord.held_by?` reads the Work's `metadata_formats`, which Atlas
includes in every Work read. Ask it before reading the record. `Work.dwc`
answers `nil` for a Work with no record, so calling it to find out costs an
Atlas read to learn nothing.

## The show page

The Darwin Core tab sits beside Metadata, and Cerberus reads its block in
`parallel_show_reads`, only for a Work that holds a record. Atlas renders the
block at `GET /works/:id/dwc.html`: one `section.dwc-group` per TDWG class, each
an `h3` and a `dl`, inside `#dwc`. Atlas owns the labels, the grouping and the
order, so Cerberus keeps no term list. An API consumer gets the same display
from one call, and there is no second labels source to drift.

To change a label's wording in Cerberus later, match the `<dt>`'s `data-term`
attribute, never its text. TDWG changes the label text when it revises the
standard.

**The tab bar now appears to guests.** Before this tab, only editors saw a bar,
because the only other pane was Analytics. A lone Metadata tab would be noise,
so the bar appears when either Darwin Core or Analytics joins it. A Work with no
record still shows a guest its MODS with no bar.

**The group headings are `h3`, the level of the work's title.** That skips no
level, so the heading order passes. `_layout.scss` sizes them down to a label,
so the title stays the page's heading.

## The download

`GET /works/:id/dwc` serves the stored XML byte for byte, as an attachment. Only
the edit pane links to it. The show tab offers no download, because v1 offered
none there and the show page's downloads are the Work's files.

The route still runs the show page's gates in the show page's order: gone when
the Work is tombstoned, refused when the reader may not read it, and not found
while the deposit is unfinished. A reader who has the URL can therefore fetch
the file only where the tab would appear.

## The edit page

The Darwin Core pane uploads a record, replaces it, or removes it, for anyone
who may edit the Work. `PUT /works/:id/dwc` runs `DarwinCoreRecordValidator`
on the file and writes nothing if it finds an error. Otherwise it calls
`put_dwc` with origin `dwc_upload`, which the History tab names "Darwin Core
upload". A `PUT` replaces the whole record, so uploading the same file twice is
safe.

`DELETE /works/:id/dwc` withdraws the record. Atlas does not purge it: the
record's history stays, and the next upload restores it.

**Atlas repeats the shape checks and answers 422.** A file that passed
`DarwinCoreRecordValidator` should never reach that, but the controller still
turns a 422 into an error on the pane. Any other refusal keeps the shared
handling in `Authorizable`.

**Both actions return with `?tab=darwin-core`, not `#darwin-core`.** Turbo
follows a redirect with fetch, and the Fetch spec strips the fragment, so a
fragment would land on the Metadata pane. The Work edit view passes
`params[:tab]` to `edit_tab_open_key`, which ignores a key the page does not
offer. The forms therefore keep Turbo, which is what runs Remove's confirm
dialog.

**Errors ride the flash as `dwc_errors`, capped at ten.** The layout renders
only the standard flash keys, so the pane renders the list itself, and the
standard alert says the record was not saved. A wrong file can break hundreds of
schema rules, and the flash is stored in the session row.

## History

A Darwin Core row on the History tab links to `/resources/:id/dwc_history`,
which diffs two versions of the record as the MODS history page does.
[`admin.md`](admin.md#the-darwin-core-page) covers the page, and
[`edit-surfaces.md`](edit-surfaces.md#where-view-points) covers the link.

## The XML loader

A manifest may carry a "Darwin Core XML File Path" column. It is optional, and
a blank cell means the row's Work gets no record. The job reads the named file
from the extracted archive, as it reads the MODS.

**The record is validated before any write.** `XmlIngestJob` runs
`DarwinCoreRecordValidator` beside `MODSRecordValidator`, so a row with a bad
record fails before its Work is created. Leaving the check to Atlas's 422 would
leave a new Work behind without the record the row asked for.

After `create_work` or `update_work`, the job calls `put_dwc` with origin
`xml_loader`. A `PUT` replaces the whole record, so a retried job writes the
same record again safely, as `update_work` relies on `put_mods`. The loader
preview validates the first row's record too, and marks each of its errors
"Darwin Core:", because the list sits under the MODS panel.

**The load report does not mark which rows attached a record.** A Work does
not need a Darwin Core record to exist, so a successful row reads the same with
or without one. A record that cannot be attached fails its row with a named
error, so nothing goes unreported when a record is refused.

The Collection metadata export writes no Darwin Core column. Reloading an
exported manifest therefore leaves each Work's record as it is.
