## Unreleased

- KYC: gallery picks (CNIC front/back, selfie) now show the in-app permission explanation and request gallery access before opening the picker (never blocks if the OS reports denied/limited).
- KYC: picks are downscaled natively (max 2400px, JPEG 88) so large Huawei/48MP photos no longer arrive as 15–25 MB files; undecodable images (e.g. HEIC) are rejected with a message.
- KYC / profile: document previews have an `errorBuilder` fallback so an undecodable image can't blank the screen.
- Profile storage: overlapping persists are coalesced and unchanged images are no longer rewritten on every KYC change.
- Android: added `<queries>` package-visibility entries for the image picker / camera.

## 1.0.0

- Initial version.
