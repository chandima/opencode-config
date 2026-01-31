# Skill Invocation Test Framework

## Overview

This framework tests whether OpenCode skills are correctly invoked when `my-plan` and `my-plan-exec` agents process specific user queries.

## Directory Structure

```
eval/
├── framework/
│   ├── schema.json       # JSON schema for test case validation
│   └── config.yaml       # Framework configuration
├── runner/
│   └── run.sh            # Main test orchestrator
├── detectors/
│   ├── skill-trigger.sh  # Detects skill invocation
│   └── tool-usage.sh     # Tracks tool usage
├── test-cases/
│   ├── my-plan/          # Test cases for my-plan agent
│   │   ├── github-ops/
│   │   ├── context7-docs/
│   │   └── security-auditor/
│   └── my-plan-exec/     # Test cases for my-plan-exec agent
│       ├── github-ops/
│       ├── context7-docs/
│       ├── security-auditor/
│       ├── skill-creator/
│       └── mcporter/
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

## Metrics

The framework tracks:
- **Skill Trigger Rate**: % of queries where correct skill was invoked
- **False Positive Rate**: % of queries where wrong skill was invoked  
- **Miss Rate**: % of queries where no skill was invoked when one should have been
- **Tool Accuracy**: Correct tool selection after skill invocation

## Implementation Status

- [x] Framework design
- [x] Directory structure
- [x] Test case schema
- [x] Configuration
- [x] Sample test cases
- [ ] Full test runner implementation
- [ ] OpenCode CLI integration
- [ ] Report generation
- [ ] CI/CD integration
