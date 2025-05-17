'use client';

import React, { useState } from 'react';
import { DataGrid, GridColDef, GridRenderCellParams, GridValueGetterParams } from '@mui/x-data-grid';
import { 
  Box, 
  Chip, 
  Paper, 
  Typography, 
  Button, 
  Dialog, 
  DialogTitle, 
  DialogContent, 
  DialogActions,
  FormControl,
  InputLabel,
  Select,
  MenuItem
} from '@mui/material';
import { Shipment, ShipmentStatus } from '@/src/types/shipment';
import { useRouter } from 'next/navigation';

interface ShipmentsGridProps {
  rows: Shipment[];
  onStatusUpdate?: (id: string, status: string) => Promise<void>;
}

const getStatusColor = (status: string) => {
  switch (status) {
    case ShipmentStatus.CREATED:
      return '#3f51b5'; // Blue
    case ShipmentStatus.PICKED_UP:
      return '#ff9800'; // Orange
    case ShipmentStatus.IN_TRANSIT:
      return '#ffeb3b'; // Yellow
    case ShipmentStatus.DELIVERED:
      return '#4caf50'; // Green
    case ShipmentStatus.EXCEPTION:
      return '#f44336'; // Red
    default:
      return '#9e9e9e'; // Grey
  }
};

export default function ShipmentsGrid({ rows, onStatusUpdate }: ShipmentsGridProps) {
  const router = useRouter();
  const [flashRow, setFlashRow] = useState<string | null>(null);
  const [statusDialogOpen, setStatusDialogOpen] = useState(false);
  const [selectedShipment, setSelectedShipment] = useState<Shipment | null>(null);
  const [newStatus, setNewStatus] = useState('');
  const [loading, setLoading] = useState(false);

  // Flash animation when a row is updated
  React.useEffect(() => {
    if (flashRow) {
      const timer = setTimeout(() => {
        setFlashRow(null);
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [flashRow]);

  const handleStatusClick = (shipment: Shipment) => {
    setSelectedShipment(shipment);
    setNewStatus(shipment.status);
    setStatusDialogOpen(true);
  };

  const handleStatusChange = async () => {
    if (!selectedShipment || !newStatus || !onStatusUpdate) return;
    
    setLoading(true);
    try {
      await onStatusUpdate(selectedShipment.id, newStatus);
      setFlashRow(selectedShipment.id);
    } catch (error) {
      console.error('Failed to update status:', error);
    } finally {
      setLoading(false);
      setStatusDialogOpen(false);
    }
  };

  const columns: GridColDef[] = [
    { field: 'id', headerName: 'ID', width: 130 },
    { field: 'owner_msp', headerName: 'Owner', width: 150 },
    { field: 'origin', headerName: 'Origin', width: 150 },
    { field: 'destination', headerName: 'Destination', width: 150 },
    { 
      field: 'status', 
      headerName: 'Status', 
      width: 160,
      renderCell: (params: GridRenderCellParams<Shipment, string>) => (
        <Chip 
          label={params.value} 
          style={{ 
            backgroundColor: getStatusColor(params.value || ''),
            color: 'white',
            fontWeight: 'bold',
            cursor: onStatusUpdate ? 'pointer' : 'default'
          }}
          onClick={onStatusUpdate ? () => handleStatusClick(params.row) : undefined}
        />
      ),
    },
    { 
      field: 'last_update', 
      headerName: 'Last Update', 
      width: 200,
      valueGetter: (params: GridValueGetterParams<Shipment, string>) => {
        const date = new Date(params.value || '');
        return date.toLocaleString();
      }
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 120,
      sortable: false,
      renderCell: (params: GridRenderCellParams<Shipment>) => (
        <Button 
          variant="outlined" 
          size="small"
          onClick={() => router.push(`/detail/${params.row.id}`)}
        >
          View
        </Button>
      ),
    },
  ];

  return (
    <Box sx={{ width: '100%' }}>
      <Paper elevation={3} sx={{ p: 2, mb: 2 }}>
        <Typography variant="h5" gutterBottom>
          Shipments Dashboard
        </Typography>
        <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 2 }}>
          <Button 
            variant="contained" 
            color="primary"
            onClick={() => router.push('/create')}
          >
            Create Shipment
          </Button>
        </Box>
        <Box sx={{ height: "100%", width: '100%' }}>
          <DataGrid
            rows={rows}
            columns={columns}
            pageSizeOptions={[5, 10, 25]}
            disableRowSelectionOnClick
            getRowClassName={(params) => 
              params.row.id === flashRow ? 'flash-animation' : ''
            }
            sx={{
              '& .flash-animation': {
                animation: 'flash 2s',
                bgcolor: 'rgba(76, 175, 80, 0.3) !important',
              },
              '@keyframes flash': {
                '0%': {
                  backgroundColor: 'rgba(76, 175, 80, 0.7)',
                },
                '100%': {
                  backgroundColor: 'transparent',
                },
              },
            }}
          />
        </Box>
      </Paper>

      {/* Status Update Dialog */}
      <Dialog open={statusDialogOpen} onClose={() => setStatusDialogOpen(false)}>
        <DialogTitle>Update Shipment Status</DialogTitle>
        <DialogContent>
          <FormControl fullWidth sx={{ mt: 2 }}>
            <InputLabel id="status-select-label">Status</InputLabel>
            <Select
              labelId="status-select-label"
              value={newStatus}
              label="Status"
              onChange={(e) => setNewStatus(e.target.value)}
            >
              {Object.values(ShipmentStatus).map((status) => (
                <MenuItem key={status} value={status}>
                  {status}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setStatusDialogOpen(false)} disabled={loading}>
            Cancel
          </Button>
          <Button 
            onClick={handleStatusChange} 
            variant="contained" 
            color="primary"
            disabled={loading || newStatus === selectedShipment?.status}
          >
            {loading ? 'Updating...' : 'Update'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}