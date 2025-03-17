package com.example.userservice.service;

import com.example.userservice.model.Entity;

import java.io.Serializable;
import java.util.List;
import java.util.Optional;

/**
 * Generic service interface for entity operations
 *
 * @param <T> the entity type
 * @param <ID> the entity identifier type
 */
public interface EntityService<T extends Entity<ID>, ID extends Serializable> {
    
    /**
     * Find an entity by ID
     * 
     * @param id the entity ID
     * @return the entity if found
     * @throws jakarta.persistence.EntityNotFoundException if entity not found
     */
    T findById(ID id);
    
    /**
     * Find an entity by ID and return as Optional
     * 
     * @param id the entity ID
     * @return Optional containing the entity if found, empty otherwise
     */
    Optional<T> findByIdOptional(ID id);
    
    /**
     * Get all entities with pagination
     * 
     * @param pageSize number of entities per page
     * @param pageNumber page number (1-based)
     * @return list of entities
     */
    List<T> findAll(int pageSize, int pageNumber);
    
    /**
     * Get total count of entities
     * 
     * @return the total count
     */
    int getCount();
    
    /**
     * Create a new entity
     * 
     * @param entity the entity to create
     * @return the created entity with ID
     */
    T create(T entity);
    
    /**
     * Update an existing entity
     * 
     * @param entity the entity with updated fields
     * @return the updated entity
     * @throws jakarta.persistence.EntityNotFoundException if entity not found
     */
    T update(T entity);
    
    /**
     * Delete an entity by ID
     * 
     * @param id the entity ID to delete
     * @return true if deleted, false if not found
     */
    boolean delete(ID id);
}