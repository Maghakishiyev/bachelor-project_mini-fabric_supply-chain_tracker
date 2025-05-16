'use client';

import React, { useEffect, useState } from 'react';
import { Alert, Snackbar, Typography, Box } from '@mui/material';
import { connectWS } from '@/src/lib/ws';

export default function BlockToast() {
    const [open, setOpen] = useState(false);
    const [blockNumber, setBlockNumber] = useState<number | null>(null);
    const [shipmentIds, setShipmentIds] = useState<string[]>([]);

    useEffect(() => {
        // subscribe to our simplified WSMessage
        const { unsubscribe } = connectWS(({ blockNumber, payload }) => {
            setBlockNumber(blockNumber);
            setShipmentIds([payload?.id]);
            setOpen(true);
        });

        return () => {
            unsubscribe();
        };
    }, []);

    // Close notification after 4 seconds
    const handleClose = () => {
        setOpen(false);
    };

    return (
        <Snackbar
            open={open}
            autoHideDuration={4000}
            onClose={handleClose}
            anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        >
            <Alert
                severity='info'
                variant='filled'
                sx={{
                    width: '100%',
                    backgroundColor: '#2196f3',
                    color: 'white',
                }}
            >
                <Box>
                    <Typography variant='subtitle1' sx={{ fontWeight: 'bold' }}>
                        New Block #{blockNumber} Committed
                    </Typography>
                    {shipmentIds.length > 0 && (
                        <Typography variant='body2'>
                            Affected shipments: {shipmentIds.join(', ')}
                        </Typography>
                    )}
                </Box>
            </Alert>
        </Snackbar>
    );
}
