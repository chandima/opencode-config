---
name: new-skill
description: Create a new OpenCode skill (invokes skill-creator)
arguments:
  - name: skill-name
    description: Name for the new skill (lowercase-kebab-case)
    required: true
  - name: quick
    description: Skip interview, just scaffold
    required: false
---

# New Skill Command

Create a new OpenCode skill using the skill-creator skill.

## Instructions

1. **Load skill-creator skill:**
   ```
   skill({ name: "skill-creator" })
   ```

2. **Determine mode from arguments:**
   - If `$ARGUMENTS` contains `--quick`: Quick mode (scaffold only)
   - Otherwise: Full mode (search + interview + generate)

3. **Pass skill name to workflow:**
   - Extract skill name from `$ARGUMENTS` (first argument, excluding flags)
   - Follow skill-creator's workflow with this name

## Usage Examples

```bash
# Full AI-assisted creation
/new-skill my-awesome-skill

# Quick scaffolding only
/new-skill my-awesome-skill --quick
```
