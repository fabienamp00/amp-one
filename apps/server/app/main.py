from fastapi import FastAPI

app = FastAPI(title='AMP One Control-Plane (Starter)', version='0.0.2')

@app.get('/health')
def health():
    return {'ok': True, 'version': '0.0.2'}