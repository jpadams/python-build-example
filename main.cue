// I run my own local registry for dev like this:
// docker run -d -p 5001:5000 --restart=always --name myregistry registry:2
//
// My workflow is to push to the local registry and then do a docker run
// on my laptop to pull the image in and test it.
// As I make changes, just incremental layers are added, so iteration is
// fast after the first pull.
package main

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/alpine"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

// This action builds a docker image from a python app.
// Build steps are defined in an inline Dockerfile.
// This is an example of a reusable definition. It uses
// the docker.#Dockerfile action provided by Dagger Universe
// and customizes it, in this case, by adding a custom
// Dockerfile :)
#PythonBuild: docker.#Dockerfile & {
	dockerfile: contents: """
		FROM python:3.9
		COPY . /app
		CMD python -c 'print("it totally works!")'
		"""
}

// this builds a custom alpine image that
// I'll use for a bash.#Run below.
#BashImage: alpine.#Build & {
	packages: {
		bash: {}
		git: {}
	}
}

dagger.#Plan & {
	// uncomment the "client" line below to see how you can write to your client
	// filesystem. In this case the tag that we'll append to the image.
	//client: filesystem: "./tag": write: contents: actions.tag.output

	actions: {
		// Notice that the single build action has sub-actions like
		// getCode, image, test, tag, push. You can invoke all of them 
		// with `dagger do build` or individually with something like
		// `dagger do build tag`    
		build: {
			// core.#Source lets you access a file system tree (dagger.#FS)
			// using a path at "." or deeper (e.g. "./foo" or "./foo/bar") with
			// optional include/exclude of specific files/directories/globs
			getCode: core.#Source & {
				path: "."
				exclude: ["cue.mod", "main.cue"]
			}
			// uses the definition at the top of the file
			pythonImage: #PythonBuild & {
				source: getCode.output
			}
			// runs a Docker container. This one always runs (no caching)
			// and uses the container image we built in the build action above.
			test: docker.#Run & {
				always: true
				input:  pythonImage.output
			}
			// runs a command in bash on copy of the local filesystem including
			// the .git directory to get an image tag based on git tag
			tag: {
				image: #BashImage
				run:   bash.#Run & {
					input:   image.output
					workdir: "/app"
					// I'm doing a transient mount to use the .git dir
					mounts: fs: {
						dest:     "/app"
						contents: getCode.output
					}
					// scripts can be in separate files, but this one is inlined
					script: contents: """
						TAG=$(git describe --tags --abbrev=0 | tr -d "[:blank:]")
						echo -n $TAG > /tmp/tag
						"""
					// export the string contents of tag file
					export: files: "/tmp/tag": string
				}
				// and allow the push action to grab it
				output: run.export.files."/tmp/tag"
			}
			// pushes the image we built to a local registry I'm running
			// using a custom tag (see top of file for registry start command)
			push: docker.#Push & {
				dest:  "localhost:5001/mypython:" + (tag.output)
				image: pythonImage.output
			}
			// outputting the image we built, tagged, pushed
			output: push.dest
		}
	}
}
