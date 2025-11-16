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


### port forward (access app from host)
```bash
sudo kubectl port-forward svc/myapp-service 8081:80 > portforward.log 2>&1 &
```


### access app from host
```bash
http://localhost:8081
```

