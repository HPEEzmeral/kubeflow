### Who can create a source control secret?

Source control secret can be created by either tenant admin or a tenant member. However, tenant member cannot list secrets. As a result, tenant members need make a note of the secret name to attach it to notebooks.

 
### Sample YAML

 
```yaml
apiVersion: v1
stringData:
  authType: token #either of token or password. If token is selected, fill "token" field with token, otherwise "password" with password
  token: my-github-token # fill this if authType is chosen as "token"
  #password: mypassword # fill this if authType is chosen as "password"
  branch: master 
  email: my.email@hpe.com
  repoURL: https://github.com/saurabh-jogalekar/workbook-repo.git
  type: github #either of "bitbucket" or "github"
  username: my-github-username
  proxyHostname: web-proxy.hpe.net #optional 
  proxyPort: "8080" #optional 
  proxyProtocol: http #http or https (optional)
kind: Secret
metadata:
  name: hpecp-sc-secret-github-saurabh-workbook
  namespace: my-ns
  labels:
    kubedirector.hpe.com/secretType: source-control
type: Opaque
```
 
#### Required fields:

1. authType

2. either of token or password

3. branch

4. email

5. repoURL

6. type

7. username

 
#### Optional fields:

1. proxyHostname

2. proxyPort

3. proxyProtocol

 
#### Things to note:
 - Source control plugin allows two auth mechanisms - a token or a password. Populate either of the `token` or `password` fields depending on the `authType` chosen. The sample YAML chooses `authType` as `token` and as a result, `token` field is populated.
 - `proxyHostname`, `proxyPort`, `proxyProtocol` are optional fields for populating proxy to clone and download code.
 - `type` can either be `bitbucket` or `github`
 - The secret requires `kubedirector.hpe.com/secretType: source-control` label.

 

 
### Attaching secret to Notebook

We attach source control secret by adding the secret name to `spec.connections.secrets` field. A Notebook App can be configured with one source control secret.  

 