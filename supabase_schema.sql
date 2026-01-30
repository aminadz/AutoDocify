-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Create profiles table (extends auth.users)
create table profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text unique not null,
  full_name text,
  language_preference text default 'en',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create documents table
create table documents (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  type text not null,
  title text,
  content text,
  form_data jsonb,
  status text default 'draft', -- draft, generating, completed, failed
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table profiles enable row level security;
alter table documents enable row level security;

-- Create policies for profiles
create policy "Users can view own profile" 
  on profiles for select 
  using ( auth.uid() = id );

create policy "Users can update own profile" 
  on profiles for update 
  using ( auth.uid() = id );

-- Create policies for documents
create policy "Users can view own documents" 
  on documents for select 
  using ( auth.uid() = user_id );

create policy "Users can insert own documents" 
  on documents for insert 
  with check ( auth.uid() = user_id );

create policy "Users can update own documents" 
  on documents for update 
  using ( auth.uid() = user_id );

create policy "Users can delete own documents" 
  on documents for delete 
  using ( auth.uid() = user_id );

-- Function to handle new user signup
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for new user signup
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
