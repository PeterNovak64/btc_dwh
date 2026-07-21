#
#   scripts/test_insert_results.py
#

from lib.insert_results import (
    load_run_results,
    extract_result_data
)

results = load_run_results(
    "target/run_results.json"
)

print(
    f"Najdenih rezultatov: {len(results['results'])}"
)

print()

for result in results["results"]:

    result_data = extract_result_data(result)

    print(result_data)

    print("-" * 80)