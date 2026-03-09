# License Note: source.mp4

- Source video path: `/workspace/ai_coding_ws/ComfyUI/input/source.mp4`
- Status: `PENDING_MANUAL_VERIFICATION`
- Probable source candidate: `Pixabay` video `man-young-beard-bald-person-light-62553`
- Candidate creator: `Engin_Akyurt`
- Candidate published date: `2021-01-26`
- Required before publish:
  - original stock source URL
  - license name / terms
  - confirmation that modification and re-publication are allowed
  - confirmation that platform distribution is allowed

Current repo state:
- local source file exists
- `source.mp4` and `source_male.mp4` are byte-identical local copies of the same clip
- local MP4 metadata only exposes `creation_time=2021-01-08T05:21:33Z`; no stock-provider URL or license text is embedded
- repo-wide text search did not reveal an upstream purchase/download URL or license document for this asset
- shell-history and browser-history checks on `2026-03-10` did not reveal a saved `pixabay` visit or download record for this asset
- publish-safe license proof is not stored in this repo yet

Inference note:
- This Pixabay asset is a strong candidate because it matches the local clip's subject matter, `3840x2160` resolution, and a publication window close to the embedded `2021-01-08` MP4 creation timestamp.
- However, the repo still lacks a direct download record or saved source URL proving that the local file was obtained from this exact page.

Candidate source details:
- URL: `https://pixabay.com/videos/man-young-beard-bald-person-light-62553/`
- License page: `https://pixabay.com/service/license-summary/`
- Pixabay's public license summary says users may use content for free, modify/adapt it, and do not need attribution, subject to prohibited uses.
