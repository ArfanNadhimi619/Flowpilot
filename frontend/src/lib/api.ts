const API = import.meta.env.VITE_API_URL || 'http://localhost:8000';
export async function api<T>(path:string, token?:string, init:RequestInit={}):Promise<T>{
 const response=await fetch(`${API}${path}`,{...init,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`} : {}),...init.headers}});
 if(!response.ok){const body=await response.json().catch(()=>({detail:'Request failed'}));throw new Error(body.detail||'Request failed');}
 return response.json();
}
