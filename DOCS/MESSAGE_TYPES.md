# Message Types

## Text
Supports:
- plain text
- emojis
- mentions in future
- links
- reply
- edit
- delete

## Image
Flow:
1. Select image
2. Show preview
3. Compress/resample
4. Upload
5. Create message document
6. Render thumbnail/full image
7. Retry failed upload

## Video
Flow:
1. Select/capture video
2. Validate duration/size
3. Generate thumbnail
4. Compress if necessary
5. Upload
6. Create message
7. Stream/play on demand

## Voice
Flow:
1. Request microphone permission
2. Press-and-hold or tap record
3. Show recording timer
4. Allow cancel
5. Encode to supported audio format
6. Upload
7. Send message with duration
8. Play with progress indicator

Do not record audio in the background without an explicit product requirement.

## File
Allowed examples:
- PDF
- DOC/DOCX
- XLS/XLSX
- PPT/PPTX
- TXT
- ZIP

Validate:
- MIME type
- file extension
- maximum size
- upload result

Never trust client-provided MIME type for security decisions.

## GIF
Store GIF provider ID plus URL/preview metadata when possible rather than blindly duplicating huge files.

## Location
Fields:
- latitude
- longitude
- accuracy
- timestamp
- optional placeName

## Live location
Fields:
- shareId
- ownerId
- latitude
- longitude
- accuracy
- startedAt
- expiresAt
- isActive

Live location must have an expiration time and explicit stop action.

## Message lifecycle
sending -> uploading -> sent -> delivered -> read

Failure:
sending/uploading -> failed -> retry/cancel
