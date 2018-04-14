# PicoFlowerDelivery

A project designed to solve the flower delivery problem for the BYU class titled 'BYU CS 462'

### Description

This repository is maintained in KRL and built ontop of picos.
Major services are containerized using docker's \'docker-compose\' cluster management.

### Getting Started

#### Dev Instructions

To start your *Flower Delivery* app:
1. Make sure that the program 'docker-compose' is installed on your machine.
2. Clone this repository
3. Navigate to the 'docker' Folder
4. Use the command ```docker-compose up``` to start the cluster
5. Note that the first time you run this it might take a while to load.
6. Additionally, you can attach to individual containers with the command ```docker-compose exec [container_name] bash```
7. When it's finished loading go to a web browser and access the page 'localhost:8080' to see the app.
8. You'll want to install the http://rulesets/root.krl ruleset into the root pico if you haven't already.

### Helpful Links

[Project Details](https://byu.instructure.com/courses/1420/assignments/66848)

[Project Assignment](https://byu.instructure.com/courses/1420/assignments/66849)

### Contributors

1. Scott Leland Crossen  
<http://scottcrossen42.com>  
<scottcrossen42@gmail.com>  
2. Trevor Rydalch  
<https://github.com/trydalch>
