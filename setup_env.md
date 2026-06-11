# Creating a Python Application Offline with All Required Libraries on Windows

Creating a Python application offline with all required libraries on Windows involves bundling the application and its dependencies. Here's a step-by-step guide:

## 1. Prepare the Environment

On a machine with internet access:

### Set up a virtual environment:
```bash
python -m venv menv
```

### Activate the virtual environment:
```bash
menv\Scripts\activate
```

### Install all required libraries:
```bash
pip install -r requirements.txt
```

### Download the libraries for offline use:
```bash
pip download -r requirements.txt -d offline_packages
```

This will save all the required `.whl` and `.tar.gz` files into the `offline_packages` folder.

## 2. Transfer Files to Offline Machine

Copy the following to the offline machine:

- Your Python script or project folder
- The `offline_packages` folder containing the downloaded libraries
- Python installer (if Python is not already installed on the offline machine)

## 3. Install Python and Libraries Offline

On the offline machine:

### Install Python (if not already installed)

### Set up a virtual environment:
```bash
python -m venv menv
```

### Activate the virtual environment:
```bash
menv\Scripts\activate
```
To prepare an offline package library based on a requirements.txt file:
pip download -r requirements.txt -d offline_packages

### Install the libraries from the offline_packages folder:
```bash
pip install --no-index --find-links=offline_packages -r requirements.txt
```

## 4. Bundle the Application into an Executable

Use a tool like PyInstaller to create a standalone executable:

### Install PyInstaller:
```bash
pip install pyinstaller
```

### Generate the executable:
```bash
pyinstaller --onefile your_script.py
```

The executable will be located in the `dist` folder.

## 5. Distribute the Application

Share the executable file from the `dist` folder. It will include all dependencies, so the target machine does not need Python installed.

## Automated Setup Script (Optional)

Create a batch file `setup_offline.bat` for automated preparation:

```batch
@echo off
echo Creating virtual environment...
python -m venv menv
call menv\Scripts\activate

echo Installing requirements...
pip install -r requirements.txt

echo Downloading packages for offline use...
mkdir offline_packages 2>nul
pip download -r requirements.txt -d offline_packages

echo Installing PyInstaller...
pip install pyinstaller

echo Creating executable...
pyinstaller --onefile app.py

echo Setup complete! Check dist folder for executable.
pause
```

---

This method ensures your Python application can run offline with all required libraries bundled. 