_default:
    @just --list

format:
    swift format format --in-place --recursive Package.swift Sources

lint:
    swift format lint --recursive Package.swift Sources
