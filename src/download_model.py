import os

from huggingface_hub import hf_hub_download

MODEL_REPO = os.environ.get("MODEL_REPO", "")
MODEL_FILENAME = os.environ.get("MODEL_FILENAME", "")
MODEL_DIR = os.environ.get("MODEL_DIR", "/models")


def download():
    if not MODEL_REPO or not MODEL_FILENAME:
        print("MODEL_REPO and MODEL_FILENAME must be set. Skipping download.")
        return

    print(f"Downloading {MODEL_FILENAME} from {MODEL_REPO}...")
    hf_hub_download(
        repo_id=MODEL_REPO,
        filename=MODEL_FILENAME,
        local_dir=MODEL_DIR,
    )
    print(f"Downloaded to {MODEL_DIR}/{MODEL_FILENAME}")


if __name__ == "__main__":
    download()
