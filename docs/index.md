# Welcome

This is a short demo of mkdocs with a few pages for your Gitlab Pages.

## What is MkDocs

"MkDocs is a **fast, simple** and **downright gorgeous** static site generator that's geared towards building project documentation. Documentation source files are written in Markdown, and configured with a single YAML configuration file. Start by reading the introductory tutorial, then check the User Guide for more information."

You can read more about MkDocs on their [website](https://www.mkdocs.org/)

### Installing MkDocs

[Here](https://www.mkdocs.org/getting-started/) you find how to install MkDocs.

``` python
pip install mkdocs
```

If you want to run a local webserver with your mkdocs, open a command console and cd into the folder of this git repository and run:

``` bash
pip install -r requirements.txt 
mkdocs serve
```

Next you can open a browser and go to http://127.0.0.1:8000

### Adding pages

The structure of the site is described in a file called *mkdocs.yml*

At the bottom of that file you will find the nav-structure:

``` yaml
...

nav:
 - Welcome: 
   - General info : index.md
   - Slides : welcome.md
```

Indentation is important to get the structure correct. Adding a page is as easy as creating a file with the .md extension (this can be in a subfolder) and adding a line to the navigation structure.

### IDE

If you like to use VS Code, there are some nice extensions for MarkDown. 

## Gitlab Pages

I have configured Continuous Integration on this git repository. This means that every time you commit and push files to the main branch, the gitlab server will try to rebuild the website.
If there is no error in your mkdocs.yml and markdown-files (when it can find all files and there are no syntax errors) then a few minutes after pushing to the repository, your gitlab pages are updated.

**The configuration of this CI (Continuous Integration) should not be changed.**

