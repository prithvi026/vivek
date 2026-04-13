# WINDOWS-SPECIFIC INSTALLATION GUIDE

## 🪟 YOU'RE ON WINDOWS - USE THESE COMMANDS

---

## PART 1: INSTALL REQUIRED TOOLS FOR WINDOWS

### Option A: Using Chocolatey (Recommended)

#### Step 1: Install Chocolatey (if not installed)

Open **PowerShell as Administrator** and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

#### Step 2: Install Tools via Chocolatey

In **PowerShell (Admin)**:
```powershell
# Install AWS CLI
choco install awscli -y

# Install kubectl
choco install kubernetes-cli -y

# Install eksctl
choco install eksctl -y

# Install Helm
choco install kubernetes-helm -y

# Verify installations
aws --version
kubectl version --client
eksctl version
helm version
```

---

### Option B: Manual Installation (Without Chocolatey)

#### 1. Install AWS CLI for Windows

**Download and Install:**
```
https://awscli.amazonaws.com/AWSCLIV2.msi
```

**Or via PowerShell:**
```powershell
# Download
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"

# Install
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\AWSCLIV2.msi /quiet" -Wait

# Verify (restart VS Code after installation)
aws --version
```

#### 2. Install kubectl for Windows

**Via PowerShell:**
```powershell
# Download kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"

# Move to a directory in PATH
Move-Item .\kubectl.exe C:\Windows\System32\

# Verify
kubectl version --client
```

#### 3. Install eksctl for Windows

**Via PowerShell:**
```powershell
# Download eksctl
$EKSCTL_VERSION = "0.172.0"
Invoke-WebRequest -Uri "https://github.com/weaveworks/eksctl/releases/download/v$EKSCTL_VERSION/eksctl_Windows_amd64.zip" -OutFile "eksctl.zip"

# Extract
Expand-Archive -Path eksctl.zip -DestinationPath C:\eksctl

# Add to PATH (restart VS Code after this)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\eksctl", "User")

# Verify
eksctl version
```

#### 4. Install Helm for Windows

**Via PowerShell:**
```powershell
# Download Helm
Invoke-WebRequest -Uri "https://get.helm.sh/helm-v3.14.0-windows-amd64.zip" -OutFile "helm.zip"

# Extract
Expand-Archive -Path helm.zip -DestinationPath C:\helm

# Move to System32
Move-Item C:\helm\windows-amd64\helm.exe C:\Windows\System32\

# Verify
helm version
```

---

## PART 2: INSTALL TRIVY FOR WINDOWS

### Method 1: Using Chocolatey (Easiest)

**In PowerShell (Admin):**
```powershell
choco install trivy -y

# Verify
trivy --version
```

### Method 2: Manual Installation

**Via PowerShell:**
```powershell
# Download Trivy
$TRIVY_VERSION = "0.48.0"
Invoke-WebRequest -Uri "https://github.com/aquasecurity/trivy/releases/download/v$TRIVY_VERSION/trivy_${TRIVY_VERSION}_Windows-64bit.zip" -OutFile "trivy.zip"

# Extract
Expand-Archive -Path trivy.zip -DestinationPath C:\trivy

# Move to System32
Move-Item C:\trivy\trivy.exe C:\Windows\System32\

# Verify
trivy --version
```

### Method 3: Using WSL2 (If you have Ubuntu installed)

**In VS Code, open WSL terminal:**
```bash
# Install Trivy in WSL
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Verify
trivy --version
```

---

## PART 3: CONFIGURE AWS CLI

### In VS Code Terminal (Git Bash or PowerShell):

```bash
# Configure AWS
aws configure

# Enter when prompted:
# AWS Access Key ID: [Your Key]
# AWS Secret Access Key: [Your Secret]
# Default region name: ap-south-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

---

## PART 4: RESTART VS CODE

**After installing all tools:**

1. Close VS Code completely
2. Reopen VS Code
3. Open new terminal (Ctrl + `)
4. Verify all installations:

```bash
aws --version
kubectl version --client
eksctl version
helm version
trivy --version
```

---

## QUICK VERIFICATION SCRIPT (Windows PowerShell)

**Copy this entire block and run in PowerShell:**

```powershell
Write-Host "=== CHECKING INSTALLED TOOLS ===" -ForegroundColor Green
Write-Host ""

Write-Host "1. AWS CLI..." -NoNewline
if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-Host " INSTALLED" -ForegroundColor Green
    aws --version
} else {
    Write-Host " MISSING" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. kubectl..." -NoNewline
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    Write-Host " INSTALLED" -ForegroundColor Green
    kubectl version --client --short
} else {
    Write-Host " MISSING" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. eksctl..." -NoNewline
if (Get-Command eksctl -ErrorAction SilentlyContinue) {
    Write-Host " INSTALLED" -ForegroundColor Green
    eksctl version
} else {
    Write-Host " MISSING" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Helm..." -NoNewline
if (Get-Command helm -ErrorAction SilentlyContinue) {
    Write-Host " INSTALLED" -ForegroundColor Green
    helm version --short
} else {
    Write-Host " MISSING" -ForegroundColor Red
}

Write-Host ""
Write-Host "5. Trivy..." -NoNewline
if (Get-Command trivy -ErrorAction SilentlyContinue) {
    Write-Host " INSTALLED" -ForegroundColor Green
    trivy --version
} else {
    Write-Host " MISSING" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== VERIFICATION COMPLETE ===" -ForegroundColor Green
```

---

## TROUBLESHOOTING WINDOWS ISSUES

### Issue: "Command not found" after installation

**Solution: Add to PATH manually**

1. Press `Windows + R`
2. Type: `sysdm.cpl` → Enter
3. Click "Environment Variables"
4. Under "User variables", select "Path"
5. Click "Edit" → "New"
6. Add these paths:
   - `C:\Program Files\Amazon\AWSCLIV2`
   - `C:\eksctl`
   - `C:\helm`
   - `C:\trivy`
7. Click OK → Restart VS Code

### Issue: "Execution policy" error in PowerShell

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Git Bash doesn't recognize commands

**Solution: Use PowerShell instead**
- In VS Code: Terminal → New Terminal → Select PowerShell
- Or: `Ctrl + Shift + P` → "Terminal: Select Default Profile" → PowerShell

---

## RECOMMENDED: USE POWERSHELL IN VS CODE

**Why?**
- ✅ Better Windows compatibility
- ✅ All tools work natively
- ✅ No sudo issues
- ✅ Easier path management

**How to switch:**
1. In VS Code, press `Ctrl + Shift + P`
2. Type: "Terminal: Select Default Profile"
3. Choose: "PowerShell"
4. Open new terminal: `Ctrl + `\`

---

## ALTERNATIVE: USE WSL2 (Windows Subsystem for Linux)

If you want Linux-like experience on Windows:

### Step 1: Install WSL2

**In PowerShell (Admin):**
```powershell
wsl --install
```

### Step 2: Restart Computer

### Step 3: Open Ubuntu from Start Menu

### Step 4: Install Tools in WSL

```bash
# Update packages
sudo apt update

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin

# Verify all
aws --version
kubectl version --client
eksctl version
helm version
trivy --version
```

### Step 5: Use WSL in VS Code

1. Install VS Code extension: "Remote - WSL"
2. Press `Ctrl + Shift + P`
3. Type: "WSL: Connect to WSL"
4. Now all Linux commands work!

---

## MY RECOMMENDATION FOR YOU

### **Option 1: Quick & Easy (Chocolatey)**
✅ Takes 10 minutes
✅ Handles everything automatically
✅ Works in PowerShell

**Do this:**
1. Open PowerShell as Admin
2. Install Chocolatey (command above)
3. Run: `choco install awscli kubectl eksctl kubernetes-helm trivy -y`
4. Restart VS Code
5. Done!

### **Option 2: Best Experience (WSL2)**
✅ True Linux environment
✅ All commands work as documented
✅ No compatibility issues

**Do this:**
1. Install WSL2: `wsl --install` (in PowerShell Admin)
2. Restart computer
3. Open Ubuntu
4. Install all tools (commands above)
5. Connect VS Code to WSL
6. Done!

---

## WHAT TO DO NOW?

**Tell me which option you prefer:**

**Option A:** Install via Chocolatey (Quick - 10 mins)
**Option B:** Install via WSL2 (Best - 30 mins)
**Option C:** Manual installation (20 mins)

**Or if you already have some tools installed, tell me which ones are working and which aren't!**

I'll guide you step-by-step based on your choice! 🚀
