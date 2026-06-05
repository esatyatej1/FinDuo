#!/bin/bash
psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
psql -c "CREATE DATABASE finduo;"
