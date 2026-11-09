# Architecture

Use a feature-first layered architecture.

lib/
  app/
    app.dart
    router/
    theme/
  core/
    constants/
    errors/
    extensions/
    network/
    permissions/
    storage/
    utils/
    widgets/
  features/
    auth/
      data/
      domain/
      presentation/
    chat/
      data/
      domain/
      presentation/
    media/
    location/
    stories/
    feed/
    profile/
    notifications/
    settings/
    search/

## Layers

### Presentation
Widgets, screens and Riverpod providers/notifiers.

Presentation must not know Firestore collection names or Storage paths.

### Domain
Entities, repository contracts and business rules.

Examples:
- Chat
- Message
- User
- Story
- Post
- Comment
- Reaction
- Attachment
- LocationShare

### Data
DTOs/models, Firebase data sources and repository implementations.

### Core
Reusable infrastructure and common utilities.

## State rules
Every asynchronous feature should represent:
- initial
- loading
- success
- empty
- error

Realtime streams should properly cancel/dispose.

## UI rules
- Prefer small reusable widgets.
- Avoid giant screen files.
- Extract message bubbles, composer, media preview, story card, post card and attachment components.
- Use const constructors where possible.
- Avoid unnecessary rebuilds.
- Use pagination for feeds, chats and search results.
