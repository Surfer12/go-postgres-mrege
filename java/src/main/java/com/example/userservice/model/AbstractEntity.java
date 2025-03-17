package com.example.userservice.model;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.io.Serializable;

/**
 * Abstract base implementation of Entity interface with common functionality
 *
 * @param <ID> the type of the entity's identifier
 * @param <E> the entity type (for fluent method chaining)
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public abstract class AbstractEntity<ID extends Serializable, E extends AbstractEntity<ID, E>> implements Entity<ID> {
    
    protected ID id;
    
    /**
     * Create a new instance with the specified ID
     * 
     * @param id the identifier
     * @return a new entity instance
     */
    public abstract E withId(ID id);
    
    /**
     * Create a copy of this entity
     * 
     * @return a deep copy of this entity
     */
    public abstract E copy();
    
    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (!(obj instanceof AbstractEntity)) return false;
        
        AbstractEntity<?, ?> other = (AbstractEntity<?, ?>) obj;
        
        // If both have IDs, compare by ID
        if (this.id != null && other.id != null) {
            return this.id.equals(other.id);
        }
        
        // Otherwise, they're not equal (unless they're the same instance, which we checked above)
        return false;
    }
    
    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : super.hashCode();
    }
}