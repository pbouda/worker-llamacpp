import os

from llama_cpp import Llama


class LlamaCppEngine:
    def __init__(self):
        model_path = os.environ.get("MODEL_PATH", "/models/model.gguf")
        n_gpu_layers = int(os.environ.get("N_GPU_LAYERS", -1))
        n_ctx = int(os.environ.get("N_CTX", 4096))

        self.llm = Llama(
            model_path=model_path,
            n_gpu_layers=n_gpu_layers,
            n_ctx=n_ctx,
        )
        self.default_batch_size = int(os.environ.get("DEFAULT_BATCH_SIZE", 5))

    def generate(self, job_input):
        messages = job_input.get("messages")
        prompt = job_input.get("prompt", "")
        stream = job_input.get("stream", False)
        sampling_params = job_input.get("sampling_params", {})

        params = {
            "temperature": sampling_params.get("temperature", 0.8),
            "top_p": sampling_params.get("top_p", 0.95),
            "top_k": sampling_params.get("top_k", 40),
            "max_tokens": sampling_params.get("max_tokens", 512),
            "repeat_penalty": sampling_params.get("repeat_penalty", 1.1),
        }
        if "stop" in sampling_params:
            params["stop"] = sampling_params["stop"]

        if messages:
            yield from self._chat_completion(messages, stream, params)
        else:
            yield from self._text_completion(prompt, stream, params)

    def _chat_completion(self, messages, stream, params):
        if stream:
            yield from self._stream_chat(messages, params)
        else:
            response = self.llm.create_chat_completion(messages=messages, **params)
            yield response

    def _text_completion(self, prompt, stream, params):
        if stream:
            yield from self._stream_completion(prompt, params)
        else:
            response = self.llm.create_completion(prompt=prompt, **params)
            yield response

    def _stream_chat(self, messages, params):
        chunks = self.llm.create_chat_completion(
            messages=messages, stream=True, **params
        )
        batch = []
        for chunk in chunks:
            delta = chunk["choices"][0].get("delta", {})
            if "content" in delta:
                batch.append(delta["content"])
                if len(batch) >= self.default_batch_size:
                    yield {"text": "".join(batch)}
                    batch = []
        if batch:
            yield {"text": "".join(batch)}

    def _stream_completion(self, prompt, params):
        chunks = self.llm.create_completion(prompt=prompt, stream=True, **params)
        batch = []
        for chunk in chunks:
            text = chunk["choices"][0].get("text", "")
            if text:
                batch.append(text)
                if len(batch) >= self.default_batch_size:
                    yield {"text": "".join(batch)}
                    batch = []
        if batch:
            yield {"text": "".join(batch)}
