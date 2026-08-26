---
name: content-prep
description: A prompt using the Ember agent from 1ES to prepare the repository content for the MicroHack repository.
agent: Ember
model: Claude Opus 4.8 (copilot)
---

Hi Ember!

Can you help me to prepare the repository content for the MicroHack repository? Here's what we need to do:

- Move the following folders to the `labautomation` folder:
  - `csvdata`
  - `databasebackup`
  - `infra`
  - `scripts`
  - `sql`
  - `src`
- Ensure that all moved content is correctly referenced in the new location, and update any paths in scripts or configuration files as necessary.
- Look through the content in `challenges` and `walkthrough` folders and move all images referenced in the markdown files from the `Images` folder to a new `images` folder under the content directory (e.g., `Images/someImage.png` referenced in a markdown file in `challenges` should be moved to `content/images/someImage.png`).

## Don't make assumptions - ask
If you're unsure about anything, please ask! We're in this together, you don't have to know everything and tackle every problem yourself.