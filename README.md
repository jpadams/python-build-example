# python-build-example

### Basic Plan:

```
actions: {
    build: {
        getCode:
        pythonImage:
        test:
        tag:
        push:
    }
}
```

### Try:
0. Clone this repo and notice there is a git tag that will be used to create the image tag.
`git log`

1. Start local registry
`docker run -d -p 5001:5000 --restart=always --name myregistry registry:2`

2. Build, tag, push
`dagger do build --log-format plain`

3. Test locally
`docker run -it --rm <your image ref in local registry>`

4. Modify the message on line 28
git add, commit, tag with new version and try steps 2 and 3 again! Repeat!

5. Extra credit:
```
docker run -it --rm <your image ref in local registry> bash
cd /app
ls
<notice what's there and what's not>
```
