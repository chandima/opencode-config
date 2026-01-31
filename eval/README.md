# Skill Invocation Test Framework

## Overview

This framework tests whether OpenCode skills are correctly invoked when `my-plan` and `my-plan-exec` agents process specific user queries.

## Directory Structure

```
eval/
├── framework/
│   ├── schema.json       # JSON schema for test case validation
│   ├── config.yaml       # Framework configuration
│   └── validate.sh       # Test case validator
├── runner/
│   └── run.sh            # Main test orchestrator
├── detectors/
│   ├── skill-trigger.sh  # Detects skill invocation
│   └── tool-usage.sh     # Tracks tool usage
├── test-cases/
│   ├── TEMPLATE.yaml     # Template for new test cases
│   ├── my-plan/          # Test cases for my-plan agent
│   │   ├── github-ops/   # 3 test cases
│   │   ├── context7-docs/# 2 test cases
│   │   └── general/      # 1 test case (no skill)
│   └── my-plan-exec/     # Test cases for my-plan-exec agent
│       ├── github-ops/   # 2 test cases
│       ├── security-auditor/ # 2 test cases
│       ├── skill-creator/# 1 test case
│       └── mcporter/     # 1 test case
├── reports/
│   └── generate.sh       # Report generator
└── ci/
    └── workflow.yml      # CI/CD integration
```

## Test Case Format

Test cases are defined in YAML format:

```yaml
test_case:
  id: unique-test-id
  agent: my-plan | my-plan-exec
  query: "User query to test"
  expected:
    skill: expected-skill-name
    skill_triggered: true | false
    tools: [list, of, expected, tools]
    agent_behavior: plan | execute | ask | delegate
  metadata:
    category: skill-category
    complexity: simple | medium | complex
    priority: 0-4
    tags: [list, of, tags]
```

## Usage

### Validate Test Cases
Before running tests, validate your test case files:
```bash
./eval/framework/validate.sh
```

### Run all tests
```bash
./eval/runner/run.sh
```

### Run tests for specific agent
```bash
./eval/runner/run.sh -a my-plan
```

### Run tests for specific skill
```bash
./eval/runner/run.sh -s github-ops
```

### Create New Test Case
Copy the template and fill in your test details:
```bash
cp eval/test-cases/TEMPLATE.yaml eval/test-cases/my-plan/github-ops/my-test.yaml
# Edit the file, then validate:
./eval/framework/validate.sh
```

## Metrics

The framework tracks:
- **Skill Trigger Rate**: % of queries where correct skill was invoked
- **False Positive Rate**: % of queries where wrong skill was invoked  
- **Miss Rate**: % of queries where no skill was invoked when one should have been
- **Tool Accuracy**: Correct tool selection after skill invocation

## Implementation Status

- [x] Framework design
- [x] Directory structure
- [x] Test case schema (JSON)
- [x] Framework configuration (YAML)
- [x] Test case validator
- [x] 12 sample test cases covering 5 skills
- [x] Test case template
- [ ] Full test runner implementation
- [ ] OpenCode CLI integration
- [ ] Report generation
- [ ] CI/CD integration

## Test Case Summary

| Agent | Skill | Count |
|-------|-------|-------|
| my-plan | github-ops | 3 |
| my-plan | context7-docs | 2 |
| my-plan | general (no skill) | 1 |
| my-plan-exec | github-ops | 2 |
| my-plan-exec | security-auditor | 2 |
| my-plan-exec | skill-creator | 1 |
| my-plan-exec | mcporter | 1 |
| **Total** | | **12** |
