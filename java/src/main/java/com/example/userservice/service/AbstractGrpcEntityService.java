package com.example.userservice.service;

import com.example.userservice.model.Entity;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.StatusRuntimeException;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.persistence.EntityNotFoundException;

import org.springframework.beans.factory.annotation.Value;

import java.io.Serializable;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

/**
 * Abstract base implementation of EntityService that communicates with a gRPC backend.
 * 
 * @param <T> the entity type
 * @param <ID> the entity identifier type
 * @param <S> the gRPC stub type
 */
public abstract class AbstractGrpcEntityService<T extends Entity<ID>, ID extends Serializable, S> implements EntityService<T, ID> {

    @Value("${grpc.server.host:mojo-db-service}")
    protected String grpcHost;

    @Value("${grpc.server.port:50051}")
    protected int grpcPort;
    
    protected ManagedChannel channel;
    protected S blockingStub;
    
    /**
     * Initialize the gRPC channel and stub
     */
    @PostConstruct
    public void init() {
        // Initialize gRPC channel
        channel = ManagedChannelBuilder.forAddress(grpcHost, grpcPort)
                .usePlaintext() // No TLS for simplicity - use TLS in production
                .build();
        
        // Create stub (specific implementation in subclasses)
        blockingStub = createStub(channel);
    }
    
    /**
     * Clean up gRPC channel
     */
    @PreDestroy
    public void destroy() {
        try {
            channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    
    /**
     * Create a gRPC stub for the specific service
     * 
     * @param channel the gRPC channel
     * @return the service stub
     */
    protected abstract S createStub(ManagedChannel channel);
    
    @Override
    public Optional<T> findByIdOptional(ID id) {
        try {
            return Optional.of(findById(id));
        } catch (EntityNotFoundException e) {
            return Optional.empty();
        } catch (StatusRuntimeException e) {
            return Optional.empty();
        }
    }
    
    /**
     * Handle common gRPC errors
     * 
     * @param e the gRPC exception
     * @param id the entity ID that was being queried
     * @throws EntityNotFoundException if the entity was not found
     */
    protected void handleGrpcError(StatusRuntimeException e, ID id) {
        String status = e.getStatus().getCode().toString();
        if (status.equals("NOT_FOUND")) {
            throw new EntityNotFoundException("Entity not found with id: " + id);
        } else {
            throw new RuntimeException("gRPC service error: " + e.getMessage(), e);
        }
    }
}