import { NextRequest, NextResponse } from 'next/server';
import { getShipment, updateShipmentStatus } from '@/src/lib/fabric';

// GET /api/shipment/[id] - Get a specific shipment
export async function GET(_request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const id = params.id;
    const shipment = await getShipment(id);
    
    if (!shipment) {
      return NextResponse.json(
        { error: `Shipment with ID ${id} not found` },
        { status: 404 }
      );
    }
    
    return NextResponse.json(shipment);
  } catch (error) {
    console.error(`Error fetching shipment ${params.id}:`, error);
    return NextResponse.json(
      { error: 'Failed to fetch shipment' },
      { status: 500 }
    );
  }
}

// PATCH /api/shipment/[id] - Update shipment status
export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const id = params.id;
    const body = await request.json();
    const { status } = body;
    
    if (!status) {
      return NextResponse.json(
        { error: 'Missing required field: status' },
        { status: 400 }
      );
    }
    
    const result = await updateShipmentStatus(id, status);
    
    if (!result.success) {
      return NextResponse.json(
        { error: result.error || 'Failed to update shipment status' },
        { status: 500 }
      );
    }
    
    return NextResponse.json({ id, success: true });
  } catch (error) {
    console.error(`Error updating shipment ${params.id}:`, error);
    return NextResponse.json(
      { error: 'Failed to update shipment' },
      { status: 500 }
    );
  }
}