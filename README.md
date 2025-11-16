# K8s Kind Installer (with Ingress Support)

## Automatic Install


## 1. Make installer executable
```bash
chmod +x install.sh
```

## 2. Install all
```bash
sudo ./install.sh
```




## Manual Install
## 1. Make installer executable
```bash
chmod +x create-cluster-with-env.sh
```

## 2. Create Kubernetes cluster
```bash
sudo ./create-cluster-with-env.sh
```

## 3. Deploy Application (Deployment + Service)

### Apply Deployment
```bash
sudo kubectl apply -f deployment.yaml
```

### Check Pods
```bash
sudo kubectl get pods
```

### Apply Service (ClusterIP)
```bash
sudo kubectl apply -f service.yaml
```

### Check Service
```bash
sudo kubectl get svc
```

## 4. Enable Ingress Support

### Step 1 — Install Ingress NGINX Controller
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/kind/deploy.yaml
```

Wait until controller is ready:
```bash
sudo kubectl wait --namespace ingress-nginx   --for=condition=Ready pod -l app.kubernetes.io/component=controller   --timeout=120s
sudo kubectl get pods -n ingress-nginx
```

### Step 2 — Apply Ingress Rule
```bash
sudo kubectl apply -f ingress.yaml
```

Check ingress:
```bash
sudo kubectl get ingress
```

## 5. Access Application via Ingress

### Add host mapping (Windows)
Edit:
```
C:\Windows\System32\drivers\etc\hosts
```

Add:
```
127.0.0.1   myapp.local
```

### Access:
```
http://myapp.local
```

## 6. (Optional) Port-forward (Quick Testing)

```bash
sudo kubectl port-forward svc/myapp-service 8081:80 > portforward.log 2>&1 &
```

Access:
```
http://localhost:8081
```
