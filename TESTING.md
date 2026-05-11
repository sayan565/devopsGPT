# DevOpsGPT — Test Coverage

## Backend Tests (Python)

| Lambda | Test File | Tests | Coverage |
|--------|-----------|-------|----------|
| `cloudwatch_poller` | `backend/lambdas/cloudwatch_poller/test_handler.py` | 5 | alert detection, SNS, DynamoDB write, error handling |
| `ai_analysis` | `backend/lambdas/ai_analysis/test_handler.py` | 5 | Bedrock call, DynamoDB write, missing fields, error handling |

### Run backend tests

```bash
pip install pytest pytest-cov boto3 moto
pytest backend/ -v --cov=backend/lambdas --cov-report=term-missing
```

### What's mocked
All boto3 clients are mocked via `unittest.mock.patch("boto3.client")`.
No real AWS calls are made during tests.

---

## Frontend Tests (Flutter/Dart)

| File | Tests | What's covered |
|------|-------|----------------|
| `test/services/api_service_test.dart` | 7 | HTTP 200/401/500, x-api-key header, empty list, POST body |
| `test/services/auth_service_test.dart` | 8 | Email validation, password strength, error code mapping, tenant ID |
| `test/widgets/dashboard_test.dart` | 5 | Loading indicator, error message, metric cards, refresh button, status banner |
| `test/widgets/alerts_test.dart` | 5 | Alert list render, severity filter chips, empty state, badge color, refresh tap |

### Run Flutter tests

```bash
cd frontend
flutter test                     # all tests
flutter test --coverage          # with lcov coverage report
flutter test test/services/      # service tests only
flutter test test/widgets/       # widget tests only
```

---

## Test Strategy

- **Backend:** Unit tests with `unittest.mock` — all AWS SDK calls mocked, no real AWS needed
- **Frontend services:** HTTP layer tested with `MockClient` from `package:http/testing`
- **Frontend widgets:** `WidgetTester` smoke tests verifying render without crashes
- **CI:** All tests run automatically on every push via `.github/workflows/ci.yml`
