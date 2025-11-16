## k8s kind installer

### chmod
```bash
chmod +x create-cluster-with-env.sh
```


### install
```bash
sudo ./create-cluster-with-env.sh
```

### deployment
```bash
kubectl apply -f deployment.yaml
```

### check pod
```bash
kubectl get pods
```

### expose
```bash
kubectl apply -f service.yaml
```


### check service
```bash
kubectl get svc
```