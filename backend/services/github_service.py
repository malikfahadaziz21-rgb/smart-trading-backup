import requests
import base64
import time
from backend.config import settings

class GitHubService:
    def __init__(self):
        self.token  = settings.GITHUB_TOKEN
        self.owner  = settings.GITHUB_REPO_OWNER
        self.repo   = settings.GITHUB_REPO_NAME
        self.headers = {
            "Authorization": f"token {self.token}",
            "Accept": "application/vnd.github.v3+json"
        }
        self.base_url = f"https://api.github.com/repos/{self.owner}/{self.repo}"

    def push_script(self, script_name: str, script_content: str) -> bool:
        url = f"{self.base_url}/contents/scripts/{script_name}"
        
        # Check if file exists (need SHA to update)
        response = requests.get(url, headers=self.headers)
        sha = response.json().get("sha") if response.status_code == 200 else None
        
        data = {
            "message": f"[auto] Add {script_name} for compilation",
            "content": base64.b64encode(script_content.encode("utf-8")).decode("utf-8")
        }
        if sha:
            data["sha"] = sha
        
        response = requests.put(url, json=data, headers=self.headers)
        return response.status_code in [200, 201]

    def trigger_workflow(self, script_name: str) -> bool:
        url = f"{self.base_url}/actions/workflows/{settings.GITHUB_WORKFLOW_FILE}/dispatches"
        
        data = {
            "ref": "main",
            "inputs": {
                "script_name": script_name
            }
        }
        
        response = requests.post(url, json=data, headers=self.headers)
        return response.status_code == 204

    def get_latest_run_id(self, script_name: str) -> str:
        # Wait a moment for GitHub to register the new run
        time.sleep(5)
        
        url = f"{self.base_url}/actions/runs"
        params = {"branch": "main", "per_page": 5}
        
        response = requests.get(url, headers=self.headers, params=params)
        runs = response.json().get("workflow_runs", [])
        
        if runs:
            return str(runs[0]["id"])
        return None

    def poll_run_completion(self, run_id: str, timeout: int = 300) -> dict:
        url = f"{self.base_url}/actions/runs/{run_id}"
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            response = requests.get(url, headers=self.headers)
            run = response.json()
            
            status     = run.get("status")      # queued, in_progress, completed
            conclusion = run.get("conclusion")   # success, failure, cancelled
            
            if status == "completed":
                return {
                    "completed": True,
                    "success": conclusion == "success",
                    "conclusion": conclusion,
                    "run_id": run_id
                }
            
            time.sleep(15)  # poll every 15 seconds
        
        return {"completed": False, "error": "Timeout waiting for compilation"}

    def download_build_log(self, run_id: str) -> str:
        # Get artifacts list
        url = f"{self.base_url}/actions/runs/{run_id}/artifacts"
        response = requests.get(url, headers=self.headers)
        artifacts = response.json().get("artifacts", [])
        
        for artifact in artifacts:
            if artifact["name"] == "build-log":
                download_url = artifact["archive_download_url"]
                zip_response = requests.get(
                    download_url,
                    headers=self.headers,
                    allow_redirects=True
                )
                
                import zipfile
                import io
                with zipfile.ZipFile(io.BytesIO(zip_response.content)) as z:
                    for name in z.namelist():
                        if name.endswith(".log"):
                            with z.open(name) as f:
                                raw = f.read()
                                # MetaEditor writes UTF-16LE
                                try:
                                    return raw.decode("utf-16-le")
                                except:
                                    return raw.decode("utf-8", errors="ignore")
        
        return "Build log not found in artifacts"
