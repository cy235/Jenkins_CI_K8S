
## Install Helm
First, let’s install Helm, the Kubernetes package manager. On Mac OS X, we’ll use brew to install. If you’re on another platform, check out the Helm docs.

Go to https://github.com/helm/helm/releases, download Helm v2.x.x (DO NOT download v3.x.x because helm init doesn't work for v3.x.x ), for Mac OS X, put the helm file in the
```
/usr/local/bin/ 
```
## Create the Tiller Service Account
Create a folder called `helm`. Here we will create all Kubernetes resources for tiller. Create a file called [helm/service-account.yml](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/helm/service-account.yml).
```
$ kubectl apply -f helm/service-account.yml
$ kubectl get serviceaccounts -n kube-system
NAME                   SECRETS   AGE
[...]
tiller                 1         3m
```
## Create the service account role binding
For demo purpose we will create a role binding to cluster-admin. Create a file called [helm/role-binding.yml](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/helm/role-binding.yml) in the helm folder.
Apply and test that the role binding exists on the cluster.
```
$ kubectl apply -f helm/role-binding.yml
$ kubectl get clusterrolebindings.rbac.authorization.k8s.io
NAME                                                   AGE
[...]
tiller                                                 4m
```
## Deploy Tiller
```
$ helm init --service-account tiller --wait
```
The --wait flag makes sure that tiller is finished before we apply the next few commands to start deploying Prometheus and Grafana.

Apply and test tiller is deployed and running
```
$ kubectl get pods -n kube-system
NAME                                   READY   STATUS   AGE
[...]
tiller-deploy-5b4685ffbf-mjqz2          1/1     Running  10m
```

## Install Prometheus
We will separate our monitoring resources into a separate namespace to keep them together.

Create a folder called `monitoring`. Here we will create all our monitoring resources.

Create a file called [monitoring/namespace.yml](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/monitoring/namespace.yml) with the content.

Apply & Test the namespace exists.

```
$ kubectl get namespaces
NAME          STATUS   AGE
[...]
monitoring    Active   5m
```

## Deploy Prometheus
Here is where the power of Helm steps in and makes life much easier.

First we need to update our local helm chart repo.

```
$ helm repo update
```

Next, deploy Prometheus into the monitoring namespace
```
$ helm install stable/prometheus --namespace monitoring --name prometheus
```

This will deploy Prometheus into your cluster in the `monitoring` namespace and mark the release with the name `prometheus`.

Prometheus is now scraping the cluster together with the node-exporter and collecting metrics from the nodes.

We can confirm by checking that the pods are running:
```
$ kubectl get pods -n monitoring
NAME                                            READY   STATUS    RESTARTS   AGE
prometheus-alertmanager-7d467fdbc6-stc7b        2/2     Running   0          126m
prometheus-kube-state-metrics-6756bbbb8-j9fm8   1/1     Running   0          126m
prometheus-node-exporter-ltqlk                  1/1     Running   0          126m
prometheus-node-exporter-n4bsb                  1/1     Running   0          126m
prometheus-pushgateway-54d5c87499-9w6bh         1/1     Running   0          126m
prometheus-server-6bc5fcfc89-m97jj              2/2     Running   0          126m
```

## Install Grafana
When deploying grafana, we need to configure it to read metrics from the right data sources.

Grafana takes data sources through yaml configs when it get provisioned.
For more information see here: http://docs.grafana.org/administration/provisioning/#datasources
Kubernetes has nothing to do with importing the data. Kubernetes merely orchestrates the injection of these yaml files.
When the Grafana Helm chart gets deployed, it will search for any config maps that contain a `grafana_datasource` label.

## Create a Prometheus data source config map
In the `monitoring` folder, create a sub-folder called `grafana`.
Here is where we will store our configs for the grafana deployment.
Create a file called [monitoring/grafana/config.yml](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/monitoring/grafana/config.yml)

Here is where we add the `grafana_datasource` label which will tell the grafana provisioner that this is a datasource it should inject.
```
labels:
    grafana_datasource: '1'
```

Apply & test the config

```
$ kubectl apply -f monitoring/grafana/config.yml
$ kubectl get configmaps -n monitoring
NAME                            DATA   AGE
[...]
grafana                         1      125m
```

## Override Grafana value
When Grafana gets deployed and the provisioner runs, the data source provisioner is deactivated. We need to activate it so it searches for our config maps.

We need to create our own values.yml file to override the datasources search value, so when Grafana is deployed it will search our datasource.yml definition and inject it.

Create a file called [monitoring/grafana/values.yml](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/monitoring/grafana/values.yml).

This will inject a sidecar which will load all the data sources into Grafana when it gets provisioned.

Now we can deploy Grafana with the overridden values.yml file and our datasource will be imported.

```
$ helm install stable/grafana -f monitoring/grafana/values.yml --namespace monitoring --name grafana
```

Check that it is running:
```
$ kubectl get pods -n monitoring
NAME                                            READY   STATUS    RESTARTS   AGE
grafana-858db5c9d4-dsh6w                        1/1     Running   0          114m
```

## Get the Grafana Password
Grafana is deployed with a password. 
```
$ kubectl get secret  --namespace monitoring grafana  -o jsonpath="{.data.admin-password}"  | base64 --decode ; echo
```
This will spit out the password to your Grafana dashboard.
The username is `admin`.

Port Forward the Grafana dashboard to see whats happening:
```
$ export POD_NAME=$(kubectl get pods --namespace monitoring| grep grafana| cut -d' ' -f1)
$ kubectl --namespace monitoring port-forward $POD_NAME 3000
```
Go to http://localhost:3000 in your browser. You should see the Grafana login screen:
![image](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/image/grafana1.jpg)

Login with the username and password you have from the previous command.

## Add a dashboard
Grafana has a long list of prebuilt dashboard here: https://grafana.com/dashboards

Here you will find many many dashboards to use. We will use this one as it is quite comprehensive in everything it tracks.

In the left hand menu, choose `Dashboards > Manage`
![image](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/image/grafana2.jpg)

In the `Grafana.com dashboard` input, add the dashboard ID we want to use: `1860` and click `Load`
![image](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/image/grafana3.jpg)

On the next screen select a name for your dashboard and select Prometheus as the datasource for it and click Import.
![image](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/image/grafana4.jpg)

Now you can see the extensive list of metrics in dashboard. 
![image](https://github.com/cy235/Jenkins_K8S_Grafana/blob/master/image/grafana5.jpg)
