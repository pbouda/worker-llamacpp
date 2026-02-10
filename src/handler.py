import os

import runpod

from engine import LlamaCppEngine

MODE_TO_RUN = os.getenv("MODE_TO_RUN", "pod")

engine = LlamaCppEngine()


def handler(job):
    job_input = job["input"]
    results_generator = engine.generate(job_input)
    for batch in results_generator:
        yield batch


if MODE_TO_RUN == "pod":
    # Pod mode: run a test request for interactive development
    def main():
        test_request = {
            "input": {
                "messages": [
                    {"role": "user", "content": "Hello! Please respond briefly."}
                ],
                "sampling_params": {"max_tokens": 100},
            }
        }
        print("Running test request in pod mode...")
        print(f"Input: {test_request}")
        print("\nResponse:")
        for batch in handler(test_request):
            print(batch)

    main()
else:
    # Serverless mode: start the RunPod worker
    runpod.serverless.start(
        {
            "handler": handler,
            "return_aggregate_stream": True,
        }
    )
