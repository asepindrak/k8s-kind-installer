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
sudo kubectl apply -f deployment.yaml
```

### check pod
```bash
sudo kubectl get pods
```

### expose
```bash
sudo kubectl apply -f service.yaml
```


### check service
```bash
sudo kubectl get svc
```