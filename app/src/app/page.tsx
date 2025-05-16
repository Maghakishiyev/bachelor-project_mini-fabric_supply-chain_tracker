'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { Container, Box } from '@mui/material';
import ShipmentsGrid from '@/src/components/ShipmentsGrid';
import BlockToast from '@/src/components/BlockToast';
import { Shipment } from '@/src/types/shipment';
import { connectWS } from '@/src/lib/ws';

export default function Home() {
    const [shipments, setShipments] = useState<Shipment[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<null | string>(null);

    const fetchShipments = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const response = await fetch('/api/shipment');
            if (!response.ok) {
                throw new Error('Failed to fetch shipments');
            }
            const data = await response.json();
            setShipments(data || []);
        } catch (error) {
            console.error('Error fetching shipments:', error);
            setError('Error fetching shipments');
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchShipments();

        const { unsubscribe } = connectWS(({ payload, blockNumber }) => {
            console.log('Home got a block #', blockNumber, ' for ', payload.id);

            fetchShipments();
        });

        return () => {
            unsubscribe();
        };
    }, [fetchShipments]);

    // Handle shipment status update
    const handleStatusUpdate = async (id: string, status: string) => {
        try {
            const response = await fetch(`/api/shipment/${id}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ status }),
            });

            if (!response.ok) {
                throw new Error('Failed to update shipment status');
            }

            // No need to manually refresh - WebSocket will trigger refresh
        } catch (error) {
            console.error('Error updating shipment status:', error);
            throw error;
        }
    };

    return (
        <Container maxWidth='xl' sx={{ py: 4 }}>
            <Box sx={{ mb: 4 }}>
                <ShipmentsGrid
                    rows={shipments}
                    onStatusUpdate={handleStatusUpdate}
                />
            </Box>
            <BlockToast />
        </Container>
    );
}
