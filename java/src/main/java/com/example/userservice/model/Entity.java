package com.example.userservice.model;

import java.io.Serializable;

/**
 * Generic interface for domain entities with an ID
 *
 * @param <ID> the type of the entity's identifier
 */
public interface Entity<ID extends Serializable> {
    
    /**
     * Get the entity's identifier
     *
     * @return the identifier
     */
    ID getId();
    
    /**
     * Set the entity's identifier
     *
     * @param id the identifier
     */
    void setId(ID id);
    
    /**
     * Validate the entity according to business rules
     *
     * @return true if valid, false otherwise
     */
    boolean validate();
    
    /**
     * Convert entity to a DTO
     *
     * @param <D> the DTO type
     * @return the DTO representation
     */
    <D> D toDto();
}