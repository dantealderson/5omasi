# Firestore Database

This document provides an overview of the Cloud Firestore database used by the **5omasi** application.

## Overview

The application uses **Cloud Firestore** as its primary database to store and synchronize data in real time.

The database is responsible for:

* User accounts and profiles
* Football match information
* Match bookings
* Player statistics
* Leaderboards
* Stadium information
* Match history
* Transactions
* Notifications

## Database Structure

A screenshot of the Firestore database structure is included in this folder:

* `firestore_collections.png`

This image illustrates the main collections and their organization within the database.

## Main Collections

The database consists of several collections that support the application's core functionality, including:

* Users
* Matches
* Stadiums
* Bookings
* Leaderboards
* Transactions
* Notifications
* Match History

Each collection is designed to minimize data duplication while supporting efficient reads and writes.

## Design Goals

The database was designed with the following objectives:

* Scalable collection structure
* Real-time data synchronization
* Fast document retrieval
* Easy maintenance and future expansion
* Secure integration with Firebase Authentication

## Technologies

* Cloud Firestore
* Firebase Authentication
* Flutter Firebase SDK

## Notes

The provided database structure reflects the implementation used during the development of the project and may evolve as new features are added.
