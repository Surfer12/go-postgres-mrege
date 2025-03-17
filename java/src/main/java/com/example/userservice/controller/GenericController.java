package com.example.userservice.controller;

import com.example.userservice.model.Entity;
import com.example.userservice.service.EntityService;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;

import java.io.Serializable;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Generic REST controller implementation for entity operations
 *
 * @param <T> the entity type
 * @param <ID> the entity identifier type
 * @param <S> the service type
 */
public abstract class GenericController<T extends Entity<ID>, ID extends Serializable, S extends EntityService<T, ID>> {

    protected final S service;

    public GenericController(S service) {
        this.service = service;
    }

    /**
     * Get entity by ID
     */
    @GetMapping("/{id}")
    public ResponseEntity<T> getById(@PathVariable ID id) {
        try {
            T entity = service.findById(id);
            return ResponseEntity.ok(entity);
        } catch (EntityNotFoundException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Entity not found", e);
        }
    }

    /**
     * Get all entities with pagination
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getAll(
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(defaultValue = "1") int pageNumber) {
        
        List<T> entities = service.findAll(pageSize, pageNumber);
        int totalCount = service.getCount();
        
        Map<String, Object> response = new HashMap<>();
        response.put("items", entities);
        response.put("totalCount", totalCount);
        response.put("pageSize", pageSize);
        response.put("pageNumber", pageNumber);
        response.put("totalPages", (int) Math.ceil((double) totalCount / pageSize));
        
        return ResponseEntity.ok(response);
    }

    /**
     * Create a new entity
     */
    @PostMapping
    public ResponseEntity<T> create(@Valid @RequestBody T entity) {
        if (!entity.validate()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid entity data");
        }
        
        T createdEntity = service.create(entity);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdEntity);
    }

    /**
     * Update an entity
     */
    @PutMapping("/{id}")
    public ResponseEntity<T> update(
            @PathVariable ID id,
            @Valid @RequestBody T entity) {
        
        if (!entity.validate()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid entity data");
        }
        
        entity.setId(id); // Ensure ID matches path variable
        
        try {
            T updatedEntity = service.update(entity);
            return ResponseEntity.ok(updatedEntity);
        } catch (EntityNotFoundException e) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Entity not found", e);
        }
    }

    /**
     * Delete an entity
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable ID id) {
        boolean deleted = service.delete(id);
        
        Map<String, Object> response = new HashMap<>();
        if (deleted) {
            response.put("success", true);
            response.put("message", "Entity deleted successfully");
            return ResponseEntity.ok(response);
        } else {
            response.put("success", false);
            response.put("message", "Entity not found");
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
        }
    }
}