# Weather App Repository

Application source + Jenkins pipeline for building and publishing images.

## Contents
- `python_app/`: Flask weather app.
- `nginx/`: Nginx container image assets.
- `Jenkinsfile`: CI pipeline (runs on dynamic k8s agent pods).
- `test_weather_app.py`: tests.

## CI Pipeline Summary
Pipeline stages in `Jenkinsfile`:
1. EKS connectivity check.
2. Connection test.
3. Full checkout.
4. Python venv + dependencies.
5. Pylint quality gate.
6. Build images with Kaniko (`latest`).
7. Prepare versioned release tags.
8. Push versioned images with Kaniko.
9. Deploy placeholder stage (main branch only).

Post actions:
- Slack success/failure notifications.
- Workspace cleanup.

## Built Images
- `omerlevyk/weather_app-app`
- `omerlevyk/weather_app-nginx`

## Local Run (optional)
```bash
cd python_app
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
python weather_app.py
```
