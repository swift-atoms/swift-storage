# Audit History

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-storage-primitives.md (2026-03-20)

**Implementation + naming audit**

HIGH=0, MEDIUM=1, LOW=2, INFO=0
Finding IDs: IMPL-002, IMPL-010, PATTERN-017, PATTERN-021

| ID | Severity | Rule | File | Line | Description |
|----|----------|------|------|------|-------------|
| STOR-001 | LOW | [IMPL-010] | Storage.Heap ~Copyable.swift | 28 | `Int(bitPattern:)` at ManagedBuffer boundary — acceptable |
| STOR-002 | LOW | [IMPL-010] | Storage.Split ~Copyable.swift | 49 | `Int(bitPattern:)` at ManagedBuffer boundary — acceptable |
| STOR-003 | MEDIUM | [API-IMPL-005] | Storage.swift | 31,59 | `Storage` enum and `Storage.Initialization` enum share one file |
