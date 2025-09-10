from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
from .db import get_db
from .models import Site

router = APIRouter(prefix="/api/v1/sites", tags=["sites"])

class SiteIn(BaseModel):
    id: str
    tenant: str
    siteId: str
    name: Optional[str] = None
    titular: Optional[str] = None
    address1: Optional[str] = None
    address2: Optional[str] = None
    postalCode: Optional[str] = None
    city: Optional[str] = None
    notes: Optional[str] = None
    createdAt: str
    updatedAt: str

class SiteOut(BaseModel):
    id: str
    tenant: str
    siteId: str
    name: Optional[str] = None
    titular: Optional[str] = None
    address1: Optional[str] = None
    address2: Optional[str] = None
    postalCode: Optional[str] = None
    city: Optional[str] = None
    notes: Optional[str] = None
    createdAt: str
    updatedAt: str

def _to_out(s: Site) -> SiteOut:
    return SiteOut(
        id=s.id, tenant=s.tenant, siteId=s.site_id,
        name=s.name, titular=s.titular,
        address1=s.address1, address2=s.address2,
        postalCode=s.postal_code, city=s.city, notes=s.notes,
        createdAt=s.created_at, updatedAt=s.updated_at
    )

@router.get("", response_model=List[SiteOut])
def list_sites(tenant: Optional[str] = Query(default=None), db: Session = Depends(get_db)):
    q = db.query(Site)
    if tenant:
        q = q.filter(Site.tenant == tenant)
    rows = q.order_by(Site.tenant, Site.site_id).all()
    return [_to_out(r) for r in rows]

@router.post("", response_model=SiteOut)
def upsert_site(payload: SiteIn, db: Session = Depends(get_db)):
    s = db.get(Site, payload.id)
    if s is None:
        s = Site(
            id=payload.id,
            tenant=payload.tenant,
            site_id=payload.siteId,
            created_at=payload.createdAt,
            updated_at=payload.updatedAt,
        )
        db.add(s)
    s.tenant = payload.tenant
    s.site_id = payload.siteId
    s.name = payload.name
    s.titular = payload.titular
    s.address1 = payload.address1
    s.address2 = payload.address2
    s.postal_code = payload.postalCode
    s.city = payload.city
    s.notes = payload.notes
    s.updated_at = payload.updatedAt
    db.commit()
    db.refresh(s)
    return _to_out(s)

@router.delete("/{id}")
def delete_site(id: str, db: Session = Depends(get_db)):
    s = db.get(Site, id)
    if not s:
        raise HTTPException(404, "site not found")
    db.delete(s)
    db.commit()
    return {"ok": True}
