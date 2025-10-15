# Git Branchs

## baseline

All the developing on functionality of the isaac tasks, aligning their performance and basic configuration with default tasks on IsaacLab and on the mean time following the evaluation function (fitness funnction) manually designed by Eureka.  

## main

## workspace
Due to the nature of AI-driven coding, which frequently modifies the codebase, an independent and isolated testing environment is necessary. This environment serves as a workspace for undertaking all the "disruptive" modifications. This branch will not be uploaded to the remote repository and easy to rebuild.

```python
# Update from main branch
git switch workspace
git fetch origin
git reset --hard origin/main
```