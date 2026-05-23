# Git

***Commits***
Every commit should have one of the following before it:

feat:
fix:
doc:

***Branches***

Branches are made for new groups of related features, and are named after the features they implement.

Protected Branches: master, develop

Committing to a protected branch should only be done with approval from at least 2 other contributors.

# Coding

***Naming***

Variables names should be in snake case, such as my_variable
Final variables should be capitalized, such as MY_VARIABLE
Functions names should be in camel case, such as myFunction
Class names should be in pascal case, such as MyClass

Folder names should be in snake case

***Folder Structure***

This is the current folder structure, to be expanded upon in the future.

res://
|__ assets/
|__ docs/
|__ scenes/
|__ scripts/

***Comments and Docstrings***

Docstrings are manditory for functions and classes.

Comments should be added before code that runs at least 5 lines, not including whitespace. Additional comments may be added as desired by the programmer.

***Bugs and Errors***

Functions should return a -1 when the code runs does not work as intended.

Errors should be thrown when code would fail to run, and re-direct the user to the home screen.