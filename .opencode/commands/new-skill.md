---
name: new-skill
description: Scaffold a new OpenCode skill with proper structure
arguments:
  - name: skill-name
    description: Name for the new skill (lowercase-kebab-case)
    required: true
---

# New Skill Scaffolding

Create a new skill directory with proper structure and boilerplate.

## Instructions

1. **Validate the skill name**: Must be `lowercase-kebab-case` (letters, numbers, hyphens only)
2. **Create the skill directory structure**:
   ```
   skills/{{skill-name}}/
   ├── SKILL.md          # From template, customize frontmatter
   └── scripts/          # Optional, create if needed
   ```

3. **Copy and customize the template**:
   - Read `@templates/skill/SKILL.md.template`
   - Replace `{{skill-name}}` with the provided name
   - Replace `{{skill-description}}` with a placeholder for the user to fill
   - Write to `skills/{{skill-name}}/SKILL.md`

4. **Inform the user** what was created and what they need to customize:
   - Update the `description` in frontmatter (critical for skill discovery)
   - Update `allowed-tools` based on what the skill needs
   - Add skill-specific documentation sections

## Validation Rules

- Name must match pattern: `^[a-z][a-z0-9-]*[a-z0-9]$`
- Name must be at least 3 characters
- Directory must not already exist

## Example Usage

```
/new-skill my-awesome-skill
```

Creates:
```
skills/my-awesome-skill/
└── SKILL.md
```
