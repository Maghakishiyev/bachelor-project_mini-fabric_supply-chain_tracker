import { NextRequest, NextResponse } from 'next/server';
import { createShipment, getAllShipments } from '@/src/lib/fabric';

// GET /api/shipment - Get all shipments
export async function GET(_request: NextRequest) {
  try {
    const result = await getAllShipments();
    return NextResponse.json(result);
  } catch (error) {
    console.error('Error in shipment API:', error);
    // Return a more detailed error message for debugging
    return NextResponse.json({ 
      error: `Failed to get shipments: ${error}`,
      message: 'If you are seeing access denied errors, check the identity and signature configuration'
    }, { status: 500 });
  }
}

// POST /api/shipment - Create a new shipment
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { id, origin, destination } = body;

    // Validate input
    if (!id || !origin || !destination) {
      return NextResponse.json(
        { error: 'Missing required fields: id, origin, destination' },
        { status: 400 }
      );
    }

    const result = await createShipment(id, origin, destination);
    
    if (!result.success) {
      return NextResponse.json(
        { error: result.error || 'Failed to create shipment' },
        { status: 500 }
      );
    }

    return NextResponse.json({ id, success: true });
  } catch (error) {
    console.error('Error creating shipment:', error);
    return NextResponse.json(
      { error: 'Failed to create shipment' },
      { status: 500 }
    );
  }
}