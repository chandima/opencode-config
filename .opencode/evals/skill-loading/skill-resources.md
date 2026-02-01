Here are **11 high-signal resources** I'd use (and recommend to teams) for writing **Agent Skills (SKILL.md)** in the **agentskills.io** format - covering **OpenAI Codex models** and **Claude models**. I'm prioritizing **primary sources** (spec + official docs + canonical example repos), then a couple of "field notes" that are unusually practical.

1. **Agent Skills Guide (practical overview + examples) - smartscope.blog**
   A concise, practical guide that summarizes skill structure, usage patterns, and authoring considerations. ([Smartscope Blog][1])

2. **Agent Skills Specification (canonical format + requirements) - agentskills.io**
   Defines the **SKILL.md frontmatter + structure**, directory conventions (scripts/references/assets), and portability expectations across toolchains. ([agentskills.io][2])

3. **Agent Skills spec + reference SDK repo - github.com/agentskills/agentskills**
   Best place for **examples + implementation details + evolution of the spec**, and a reliable "source of truth" beyond the marketing pages. ([GitHub][3])

4. **OpenAI Codex: Agent Skills docs (how Codex discovers/loads skills, progressive disclosure)**
   OpenAI's official guidance on structuring skills for **Codex CLI / IDE**, including the "progressive disclosure" model (small SKILL.md + optional references/scripts). ([OpenAI Developers][4])

5. **OpenAI Codex: AGENTS.md guide (instruction layering + overrides)**
   Not SKILL.md itself, but essential for *practical deployment*: how Codex loads **global/root/local** `AGENTS.md` and how to place overrides close to code to reduce confusion. ([OpenAI Developers][5])

6. **OpenAI: "Testing Agent Skills Systematically with Evals" (how to evaluate skill quality)**
   A strong playbook for turning skills into **testable behavior** (deterministic checks + rubric) so you can iterate like software. ([OpenAI Developers][6])

7. **Claude API Docs: "Skill authoring best practices" (limits + patterns + directory design)**
   Anthropic's most direct guidance on writing maintainable skills: size guidance, splitting content, and patterns for references/examples/scripts. ([Claude Developer Platform][7])

8. **Claude Code Docs: "Extend Claude with skills" (product behavior + invocation model)**
   Practical details on how skills are **used/invoked in Claude Code**, including the UX layer (e.g., direct invocation patterns). ([Claude Code][8])

9. **Anthropic engineering blog: "Equipping agents for the real world with Agent Skills" (design philosophy)**
   Why skills work, how to think about modularizing procedural knowledge, and pitfalls when you scale skill libraries. ([Anthropic][9])

10. **anthropics/skills (open-source skill library + templates)**
   A large set of **real skills** you can study for structure, naming, routing-friendly descriptions, and how they split references/scripts. ([GitHub][10])

11. **openai/skills (Codex skill catalog) + "porting skills to Codex" field notes**
    Useful for seeing what "good" looks like in the Codex ecosystem, plus a practical write-up on porting the SKILL.md system into Codex CLI. ([GitHub][11])

If you tell me whether you're targeting **Codex CLI**, **Claude Code**, or both, I can narrow this to the *best 5* for that exact environment and include "what to copy" (templates + do/don't) from each.

[1]: https://smartscope.blog/en/blog/agent-skills-guide/ "Agent Skills Guide - Smartscope Blog"
[2]: https://agentskills.io/specification?utm_source=chatgpt.com "Specification - Agent Skills"
[3]: https://github.com/agentskills/agentskills?utm_source=chatgpt.com "Specification and documentation for Agent Skills - GitHub"
[4]: https://developers.openai.com/codex/skills?utm_source=chatgpt.com "Agent Skills - developers.openai.com"
[5]: https://developers.openai.com/codex/guides/agents-md?utm_source=chatgpt.com "Custom instructions with AGENTS.md - developers.openai.com"
[6]: https://developers.openai.com/blog/eval-skills?utm_source=chatgpt.com "Testing Agent Skills Systematically with Evals"
[7]: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices?utm_source=chatgpt.com "Skill authoring best practices - Claude API Docs"
[8]: https://code.claude.com/docs/en/skills?utm_source=chatgpt.com "Extend Claude with skills - Claude Code Docs"
[9]: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills?utm_source=chatgpt.com "Equipping agents for the real world with Agent Skills \\ Anthropic"
[10]: https://github.com/anthropics/skills?utm_source=chatgpt.com "GitHub - anthropics/skills: Public repository for Agent Skills"
[11]: https://github.com/openai/skills?utm_source=chatgpt.com "GitHub - openai/skills: Skills Catalog for Codex"
