"""
pytest configuration — adds Lambda directories to sys.path so
test files can import handler modules directly.
"""
import sys
import os

# Add each Lambda directory to path so `from handler import handler` works
lambdas_dir = os.path.join(os.path.dirname(__file__), "lambdas")
for fn in os.listdir(lambdas_dir):
    fn_path = os.path.join(lambdas_dir, fn)
    if os.path.isdir(fn_path):
        sys.path.insert(0, fn_path)

# Add shared directory
sys.path.insert(0, os.path.join(lambdas_dir, "shared"))
