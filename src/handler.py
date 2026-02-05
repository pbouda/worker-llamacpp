import runpod
from engine import LlamaCppEngine

engine = LlamaCppEngine()


def handler(job):
    job_input = job["input"]
    results_generator = engine.generate(job_input)
    for batch in results_generator:
        yield batch


runpod.serverless.start(
    {
        "handler": handler,
        "return_aggregate_stream": True,
    }
)
