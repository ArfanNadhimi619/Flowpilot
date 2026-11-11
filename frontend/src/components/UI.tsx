import type { ReactNode } from 'react';
export function Card({children,className=''}:{children:ReactNode,className?:string}){return <section className={`card ${className}`}>{children}</section>}
export function SectionTitle({title,sub,action}:{title:string,sub?:string,action?:ReactNode}){return <div className="section-title"><div><h2>{title}</h2>{sub&&<p>{sub}</p>}</div>{action}</div>}
export function StatCard({label,value,change,icon:Icon,tone='violet'}:any){return <Card><div className="stat-top"><span>{label}</span><span className={`stat-icon ${tone}`}><Icon size={18}/></span></div><div className="stat-value">{value}</div><div className="stat-change">{change}</div></Card>}
export function Badge({children,tone='green'}:{children:ReactNode,tone?:string}){return <span className={`badge ${tone}`}>{children}</span>}
export function Avatar({name}:{name:string}){return <span className="avatar">{name.split(' ').map(x=>x[0]).slice(0,2).join('').toUpperCase()}</span>}
