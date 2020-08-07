## Things I've waved at as I've gone by

* Dealing with automated semtag versioning. This is acting as a monorepo that not only has application code/images, but also deployment. The standard way of tagging a repo needs to be massaged to deal with the monorepo concept.  For now I'm just going to add manual version files to paths that want to maintain independent versions, and try to impose immutable images in the repositories to prevent accidental overwrites.

