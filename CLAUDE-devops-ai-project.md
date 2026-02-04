# CLAUDE.md - DevOps AI Project Guidelines

## 🏗️ Automation Architecture

This project uses a combination of CLAUDE.md, Subagents, Skills, and Hooks to ensure quality and consistency.

### Structure
```
.claude/
├── agents/
│   ├── content-manager.md    # Manages sites and PT/EN synchronization
│   ├── product-builder.md    # Builds and chapter creation
│   └── chapter-updater.md    # Updates chapters with research and practical examples
├── skills/
│   ├── publish-update/       # /publish-update - Complete publish workflow
│   ├── new-chapter/          # /new-chapter - Create new chapter/section
│   └── add-release-note/     # /add-release-note - Add release note entry
└── settings.json             # Automatic validation hooks

scripts/
└── check-portuguese-accents.py  # Accent validator (for PT-BR content)
```

### Available Skills (Slash Commands)
- `/publish-update` - Complete publish workflow
- `/new-chapter` - Create new chapter or section
- `/add-release-note` - Add entry to Release Notes

### Available Agents

| Agent | When to Use |
|-------|-------------|
| `content-manager` | Content synchronization between PT/EN sites |
| `product-builder` | Product builds and new chapter creation |
| `chapter-updater` | **Update existing chapter** with best practices research, practical examples, and step-by-step |

**Tip**: To improve an existing chapter (superficial, outdated, without examples), use `chapter-updater`. It researches current practices (2025-2026), compares tools, and rewrites with senior quality.

---

## 🌐 Site Updates

When making changes to site pages/content:
- **Always update both directories:**
  - `site-devops-ai` (PT-BR)
  - `site-devops-ai-en` (EN)
- Keep the corresponding language for each version

## 📚 Product/Chapter Updates

When updating chapter content:
- **Always update both:**
  - `product` (PT-BR)
  - `product-en` (EN)
- Keep the corresponding language for each version
- If skills or .md files are created, place them in the templates directory (./devopsai-templates)

## 📋 Material Update Checklist

When adding/modifying any material, **never forget to update:**

### Landing Pages
- [ ] `site-devops-ai/index.html` - "Complete Index" section
- [ ] `site-devops-ai-en/index.html` - "Complete Table of Contents"

### Table of Contents
- [ ] `site-devops-ai/sumario.html` - Complete table of contents
- [ ] `site-devops-ai-en/table-of-contents.html` - Full table of contents

### Previews (Sidebar Menu)
- [ ] `site-devops-ai/preview/index.html` - PT preview sidebar menu
- [ ] `site-devops-ai-en/preview/index.html` - EN preview sidebar menu

### Release Notes
- [ ] `site-devops-ai/release-notes.html` - PT history (with accents!)
- [ ] `site-devops-ai-en/release-notes.html` - EN update history

### Update Dates
- [ ] `product/build.sh` → "Ultima atualizacao: DD/MM/YYYY"
- [ ] `product-en/build.sh` → "Last updated: Mon DD, YYYY"

### Reference Chapters
- [ ] `product/chapters/chapter-1.html` - References to new additions
- [ ] `product/chapters/chapter-15.html` - References to new additions
- [ ] Corresponding EN versions

### Public Templates (IF APPLICABLE)
- [ ] `devopsai-templates/` - Copy new CLAUDE.md, skills, or subagents
- [ ] `git push` on devopsai-templates repository

## 📝 Release Notes

When adding significant content, document on the Release Notes page:
- Update date
- Section/chapter added or modified
- Brief description of what was included
- This demonstrates the guide is always up-to-date

## ✨ Standards for New Content

When adding any new material:
1. **Research** current best practices before writing
2. **Provide** senior and concrete examples
3. **Include** rich context in the introduction
4. **Avoid** generic or superficial content

## 🇧🇷 Portuguese Accents (for PT-BR content)

**ALWAYS use correct accents** in all Portuguese content (PT-BR):
- Use: ã, á, à, â, é, ê, í, ó, ô, õ, ú, ç
- Correct examples: seção, não, atualização, histórico, capítulo, versão, automação, integração
- **Never** write Portuguese without accents (e.g., "secao" instead of "seção")
- Check common words: você, está, será, também, através, após, até, além, já, só

### Validation Hook
The project has an automatic hook that validates accents after edits to Portuguese HTML files. If problems are found, a warning will be displayed.

## 🔧 Installations and Tools

When mentioning installations, MCP servers, tools, etc:
- **Always verify** the latest available version
- **Include** updated installation commands
- **Validate** compatibility with recent versions

## 🚀 Git Workflow

### Sites (`site-devops-ai` and `site-devops-ai-en`)
- **Always run `git push`** after commits
- Ensure automatic deploy is triggered

```bash
# Example commit for sites
cd site-devops-ai
git add .
git commit -m "Update: description

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push
```

### Templates (`devopsai-templates`) - MANDATORY

**Whenever creating a new template (CLAUDE.md, skill, subagent, etc.), you MUST:**

1. **LANGUAGE: ALWAYS IN ENGLISH**
   - All templates, skills, and subagents are written in **ENGLISH**
   - Even if PT-BR product content is in Portuguese, templates are in English
   - This ensures international accessibility of the public repository

2. **Copy to public repository:**
   ```bash
   cp <file> /path/to/devopsai-templates/
   ```

3. **Directory structure:**
   ```
   devopsai-templates/
   ├── CLAUDE-*.md          # CLAUDE.md templates (English)
   ├── skills/              # Skills organized by category (English)
   │   ├── kubernetes/
   │   ├── terraform/
   │   ├── security/
   │   └── ...
   ├── subagents/           # Subagent definitions (English)
   ├── claude-settings.json # Configuration example
   └── README.md            # Documentation
   ```

4. **Commit and push:**
   ```bash
   cd /path/to/devopsai-templates
   git add .
   git commit -m "Add: [template name]

   - Brief description

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
   git push
   ```

**Examples of templates that should be added:**
- New `CLAUDE-*.md` files created for specific projects
- New skills (`/skill-name`)
- New subagents
- Reusable configuration files

**IMPORTANT:** This step CANNOT be forgotten. The `devopsai-templates` repository is the public repository with templates for guide buyers.

### Products
- Always build both after updates:
```bash
cd product && ./build.sh
cd product-en && ./build.sh
```

---

## 📁 Project Structure

```
DevOps-AI/
├── site-devops-ai/           # Landing page PT-BR
│   ├── index.html
│   ├── sumario.html
│   ├── release-notes.html
│   └── preview/index.html
│
├── site-devops-ai-en/        # Landing page EN
│   ├── index.html
│   ├── table-of-contents.html
│   ├── release-notes.html
│   └── preview/index.html
│
├── product/                  # Product PT-BR
│   ├── build.sh
│   └── chapters/
│
├── product-en/               # Product EN
│   ├── build.sh
│   └── chapters/
│
├── devopsai-templates/       # Public templates and skills
│
├── .claude/                  # Claude Code configuration
│   ├── agents/
│   ├── skills/
│   └── settings.json
│
├── scripts/                  # Automation scripts
│   └── check-portuguese-accents.py
│
└── CLAUDE.md                 # This file
```
