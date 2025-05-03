'use client';

import React, { useState } from 'react';
import { 
  Box, 
  Paper, 
  Typography, 
  TextField, 
  Button, 
  Stepper, 
  Step, 
  StepLabel,
  Alert,
  CircularProgress
} from '@mui/material';
import { useRouter } from 'next/navigation';
import { ShipmentInput } from '@/src/types/shipment';

const steps = ['Enter Shipment Details', 'Confirm Details', 'Submit'];

interface ShipmentFormProps {
  onSubmit: (data: ShipmentInput) => Promise<{ success: boolean; error?: string }>;
}

export default function ShipmentForm({ onSubmit }: ShipmentFormProps) {
  const router = useRouter();
  const [activeStep, setActiveStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState<ShipmentInput>({
    id: '',
    origin: '',
    destination: ''
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    if (error) setError(null);
  };

  const handleNext = () => {
    // Validate current step before proceeding
    if (activeStep === 0) {
      // Validate first step - all fields are required
      if (!formData.id || !formData.origin || !formData.destination) {
        setError('All fields are required');
        return;
      }
      
      // ID format validation (optional)
      if (!/^[A-Za-z0-9_-]{3,16}$/.test(formData.id)) {
        setError('ID must be 3-16 alphanumeric characters, with dashes or underscores');
        return;
      }
    }
    
    setActiveStep(prevStep => prevStep + 1);
  };

  const handleBack = () => {
    setActiveStep(prevStep => prevStep - 1);
    setError(null);
  };

  const handleSubmit = async () => {
    setLoading(true);
    setError(null);
    
    try {
      const result = await onSubmit(formData);
      
      if (!result.success) {
        setError(result.error || 'An error occurred while creating the shipment');
        setActiveStep(0);
        return;
      }
      
      // Success - go to final step
      setActiveStep(3);
    } catch (error) {
      console.error('Error submitting shipment:', error);
      setError('Failed to create shipment. Please try again.');
      setActiveStep(0);
    } finally {
      setLoading(false);
    }
  };

  const handleReturn = () => {
    router.push('/');
  };

  const renderStepContent = () => {
    switch (activeStep) {
      case 0:
        return (
          <Box sx={{ mt: 2 }}>
            <TextField
              fullWidth
              margin="normal"
              label="Shipment ID"
              name="id"
              value={formData.id}
              onChange={handleChange}
              required
              helperText="Unique identifier for the shipment"
            />
            <TextField
              fullWidth
              margin="normal"
              label="Origin"
              name="origin"
              value={formData.origin}
              onChange={handleChange}
              required
              helperText="Starting location of the shipment"
            />
            <TextField
              fullWidth
              margin="normal"
              label="Destination"
              name="destination"
              value={formData.destination}
              onChange={handleChange}
              required
              helperText="Final destination of the shipment"
            />
          </Box>
        );
      case 1:
        return (
          <Box sx={{ mt: 2 }}>
            <Typography variant="h6" gutterBottom>
              Review Shipment Details
            </Typography>
            <Box sx={{ pl: 2 }}>
              <Typography variant="body1"><strong>Shipment ID:</strong> {formData.id}</Typography>
              <Typography variant="body1"><strong>Origin:</strong> {formData.origin}</Typography>
              <Typography variant="body1"><strong>Destination:</strong> {formData.destination}</Typography>
            </Box>
            <Typography sx={{ mt: 2, color: 'text.secondary' }}>
              Please verify that the information above is correct before submitting.
              Once submitted, the shipment will be recorded on the blockchain and cannot be edited.
            </Typography>
          </Box>
        );
      case 2:
        return (
          <Box sx={{ mt: 2, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            {loading ? (
              <>
                <CircularProgress />
                <Typography sx={{ mt: 2 }}>
                  Recording shipment on the blockchain...
                </Typography>
              </>
            ) : (
              <Typography>
                Ready to submit. Click "Submit" to create this shipment.
              </Typography>
            )}
          </Box>
        );
      case 3:
        return (
          <Box sx={{ mt: 2, textAlign: 'center' }}>
            <Alert severity="success" sx={{ mb: 2 }}>
              Shipment created successfully!
            </Alert>
            <Typography variant="body1" paragraph>
              Shipment <strong>{formData.id}</strong> has been recorded on the blockchain.
            </Typography>
            <Typography variant="body2" color="text.secondary">
              You can track this shipment on the dashboard.
            </Typography>
          </Box>
        );
      default:
        return null;
    }
  };

  return (
    <Box sx={{ width: '100%', maxWidth: 800, mx: 'auto' }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <Typography variant="h4" align="center" gutterBottom>
          Create New Shipment
        </Typography>
        
        <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
          {steps.map((label) => (
            <Step key={label}>
              <StepLabel>{label}</StepLabel>
            </Step>
          ))}
        </Stepper>
        
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}
        
        {renderStepContent()}
        
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 4 }}>
          {activeStep === 3 ? (
            <Button 
              variant="contained" 
              color="primary" 
              onClick={handleReturn}
              fullWidth
            >
              Return to Dashboard
            </Button>
          ) : (
            <>
              <Button 
                disabled={activeStep === 0 || loading}
                onClick={handleBack}
              >
                Back
              </Button>
              <Box>
                <Button 
                  variant="contained" 
                  color="primary"
                  onClick={activeStep === 2 ? handleSubmit : handleNext}
                  disabled={loading}
                >
                  {activeStep === 2 ? 'Submit' : 'Next'}
                </Button>
                <Button 
                  onClick={handleReturn}
                  sx={{ ml: 1 }}
                  disabled={loading}
                >
                  Cancel
                </Button>
              </Box>
            </>
          )}
        </Box>
      </Paper>
    </Box>
  );
}