from fastapi import FastAPI
import uvicorn

app = FastAPI(title="TEST_API")

@app.get("/my-profile")
async def test():
    return {"message": "Працює!"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)